use std::{
    io::{self, BufRead, IsTerminal},
    path::PathBuf,
    process::{Child, Command, Stdio},
    sync::mpsc::{self, Receiver, TryRecvError},
    thread,
    time::{Duration, Instant},
};

use anyhow::{Context, Result, bail};
use crossterm::{
    event::{
        self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, KeyEventKind, MouseEventKind,
    },
    execute,
    terminal::{EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode},
};
use ratatui::{
    Terminal,
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Cell, Clear, Paragraph, Row, Table, TableState, Wrap},
};

use crate::{
    model::{Service, ServiceState},
    operations::{self, ExecOptions, UpdateReport},
    privilege, quadlet, systemd,
};

type Backend = CrosstermBackend<io::Stdout>;

struct TerminalSession {
    terminal: Terminal<Backend>,
}

impl TerminalSession {
    fn enter() -> Result<Self> {
        enable_raw_mode()?;
        let mut stdout = io::stdout();
        execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
        Ok(Self {
            terminal: Terminal::new(CrosstermBackend::new(stdout))?,
        })
    }
}

impl Drop for TerminalSession {
    fn drop(&mut self) {
        let _ = disable_raw_mode();
        let _ = execute!(
            self.terminal.backend_mut(),
            DisableMouseCapture,
            LeaveAlternateScreen
        );
        let _ = self.terminal.show_cursor();
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Focus {
    Services,
    Logs,
}

impl Focus {
    fn next(self) -> Self {
        match self {
            Self::Services => Self::Logs,
            Self::Logs => Self::Services,
        }
    }
}

#[derive(Debug, Clone)]
struct ActionResult {
    service: String,
    action: String,
    result: std::result::Result<(), String>,
}

#[derive(Debug, Clone)]
struct UpdateDone {
    result: std::result::Result<Vec<UpdateReport>, String>,
}

#[derive(Debug, Clone)]
enum WorkDone {
    Action(ActionResult),
    Update(UpdateDone),
}

#[derive(Debug, Clone)]
struct PendingConfirm {
    action: String,
    service: String,
}

/// Maximum retained log lines per service in the dashboard.
const LOG_LINE_CAP: usize = 2000;

fn push_log_line(logs: &mut String, line: &str) {
    logs.push_str(line);
    logs.push('\n');
    let count = logs.lines().count();
    if count > LOG_LINE_CAP
        && let Some(index) = logs
            .match_indices('\n')
            .nth(count - LOG_LINE_CAP - 1)
            .map(|(index, _)| index + 1)
    {
        logs.drain(..index);
    }
}

/// A `journalctl -f` follower streaming lines to the UI thread.
///
/// Dropping kills the child, so switching selection never leaks followers.
struct LogStream {
    child: Child,
    rx: Receiver<Option<String>>,
}

impl LogStream {
    fn spawn(unit: &str) -> Result<Self> {
        let mut child = Command::new("journalctl")
            .args(["-u", unit, "-n", "200", "-f", "-o", "cat", "--no-pager"])
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()
            .context("start journalctl follower")?;
        let stdout = child.stdout.take().context("capture journalctl output")?;
        let (tx, rx) = mpsc::channel();
        thread::spawn(move || {
            for line in std::io::BufReader::new(stdout).lines() {
                match line {
                    Ok(line) => {
                        if tx.send(Some(line)).is_err() {
                            break;
                        }
                    }
                    Err(_) => break,
                }
            }
            let _ = tx.send(None);
        });
        Ok(Self { child, rx })
    }
}

impl Drop for LogStream {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

pub struct App {
    dir: PathBuf,
    dry_run: bool,
    timeout: Duration,
    refresh_interval: Duration,
    services: Vec<Service>,
    selected_name: Option<String>,
    table_state: TableState,
    focus: Focus,
    logs: String,
    log_stream: Option<LogStream>,
    log_scroll: u16,
    log_view_height: u16,
    follow_logs: bool,
    message: String,
    confirm: Option<PendingConfirm>,
    filter: String,
    filtering: bool,
    show_help: bool,
    paused: bool,
    global_error: Option<String>,
    action_rx: Option<Receiver<WorkDone>>,
    action_in_progress: Option<(String, String)>,
    last_refresh: Instant,
}

impl App {
    pub fn new(
        dir: PathBuf,
        dry_run: bool,
        timeout: Duration,
        refresh_interval: Duration,
    ) -> Result<Self> {
        let mut app = Self {
            dir,
            dry_run,
            timeout,
            refresh_interval,
            services: Vec::new(),
            selected_name: None,
            table_state: TableState::default(),
            focus: Focus::Services,
            logs: String::new(),
            log_stream: None,
            log_scroll: 0,
            log_view_height: 1,
            follow_logs: true,
            message: String::new(),
            confirm: None,
            filter: String::new(),
            filtering: false,
            show_help: false,
            paused: false,
            global_error: None,
            action_rx: None,
            action_in_progress: None,
            last_refresh: Instant::now(),
        };
        app.refresh();
        Ok(app)
    }

    fn matches_filter(&self, service: &Service) -> bool {
        if self.filter.is_empty() {
            return true;
        }
        let query = self.filter.to_lowercase();
        service.name.to_lowercase().contains(&query)
            || service.container_name.to_lowercase().contains(&query)
            || service
                .image
                .as_deref()
                .unwrap_or_default()
                .to_lowercase()
                .contains(&query)
            || service.state.label().to_lowercase().contains(&query)
    }

    fn visible_services(&self) -> Vec<&Service> {
        self.services
            .iter()
            .filter(|service| self.matches_filter(service))
            .collect()
    }

    fn sync_selection(&mut self) {
        let names: Vec<String> = self
            .visible_services()
            .iter()
            .map(|service| service.name.clone())
            .collect();
        if names.is_empty() {
            self.selected_name = None;
            self.table_state.select(None);
            return;
        }
        let index = self
            .selected_name
            .as_deref()
            .and_then(|name| names.iter().position(|candidate| candidate == name))
            .unwrap_or(0);
        self.selected_name = Some(names[index].clone());
        self.table_state.select(Some(index));
    }

    /// Re-resolve the selection after the list changes; restart log
    /// streaming only when the selected service actually changed.
    fn reselect(&mut self) {
        let before = self.selected_name.clone();
        self.sync_selection();
        if self.selected_name != before {
            self.follow_logs = true;
            self.restart_log_stream();
        }
    }

    fn selected_service(&self) -> Option<&Service> {
        let name = self.selected_name.as_ref()?;
        self.services.iter().find(|service| &service.name == name)
    }

    fn refresh(&mut self) {
        // State refresh never restarts log streaming; the follower keeps
        // tailing the selected unit across refreshes.
        match quadlet::discover(&self.dir) {
            Ok(mut services) => {
                self.global_error = systemd::refresh_services(&mut services)
                    .err()
                    .map(|error| error.to_string());
                self.services = services;
                self.reselect();
                self.last_refresh = Instant::now();
            }
            Err(error) => self.global_error = Some(error.to_string()),
        }
    }

    fn restart_log_stream(&mut self) {
        // Dropping the previous stream kills its journalctl child.
        self.log_stream = None;
        self.logs.clear();
        self.log_scroll = 0;
        let Some(service) = self.selected_service() else {
            self.logs = "No service selected.".into();
            return;
        };
        match LogStream::spawn(&service.unit) {
            Ok(stream) => self.log_stream = Some(stream),
            Err(_) => self.logs = "No logs available.".into(),
        }
    }

    fn poll_logs(&mut self) {
        let mut batch = Vec::new();
        let mut ended = false;
        if let Some(stream) = self.log_stream.as_ref() {
            loop {
                match stream.rx.try_recv() {
                    Ok(Some(line)) => batch.push(line),
                    Ok(None) | Err(TryRecvError::Disconnected) => {
                        ended = true;
                        break;
                    }
                    Err(TryRecvError::Empty) => break,
                }
            }
        }
        for line in batch {
            push_log_line(&mut self.logs, &line);
        }
        if ended {
            self.log_stream = None;
            if self.logs.is_empty() {
                self.logs = "No logs available.".into();
            }
        } else if self.follow_logs {
            self.log_scroll = self.max_log_scroll();
        } else {
            self.log_scroll = self.log_scroll.min(self.max_log_scroll());
        }
    }

    fn max_log_scroll(&self) -> u16 {
        self.logs
            .lines()
            .count()
            .saturating_sub(self.log_view_height.max(1) as usize) as u16
    }

    fn scroll_logs_to_latest(&mut self) {
        self.log_scroll = self.max_log_scroll();
        self.follow_logs = true;
    }

    fn cycle_focus(&mut self) {
        self.focus = self.focus.next();
    }

    fn scroll_logs(&mut self, delta: i32) {
        let max_scroll = self.max_log_scroll();
        self.log_scroll = if delta.is_negative() {
            self.follow_logs = false;
            self.log_scroll.saturating_sub(delta.unsigned_abs() as u16)
        } else {
            self.log_scroll.saturating_add(delta as u16).min(max_scroll)
        };
        self.follow_logs = self.log_scroll >= max_scroll;
    }

    fn move_selection(&mut self, delta: isize) {
        let visible: Vec<String> = self
            .visible_services()
            .iter()
            .map(|service| service.name.clone())
            .collect();
        if visible.is_empty() {
            return;
        }
        let current = self
            .selected_name
            .as_deref()
            .and_then(|name| visible.iter().position(|candidate| candidate == name))
            .unwrap_or(0) as isize;
        let next = (current + delta).rem_euclid(visible.len() as isize) as usize;
        self.selected_name = Some(visible[next].clone());
        self.sync_selection();
        self.follow_logs = true;
        self.restart_log_stream();
    }

    fn request_action(&mut self, action: &str) {
        if self.action_in_progress.is_some() {
            self.message = "an action is already running".into();
            return;
        }
        let Some(service) = self.selected_service() else {
            return;
        };
        if action == "start" {
            self.start_action(action);
            return;
        }
        // stop/restart are destructive: require confirmation first.
        self.confirm = Some(PendingConfirm {
            action: action.to_owned(),
            service: service.name.clone(),
        });
    }

    fn confirm_pending(&mut self, accept: bool) {
        let Some(pending) = self.confirm.take() else {
            return;
        };
        if !accept {
            self.message = format!("{} {} cancelled", pending.action, pending.service);
            return;
        }
        if self
            .services
            .iter()
            .any(|service| service.name == pending.service)
        {
            self.selected_name = Some(pending.service.clone());
            self.sync_selection();
            if pending.action == "update" {
                self.start_update();
            } else {
                self.start_action(&pending.action);
            }
        } else {
            self.message = format!("{} is no longer available", pending.service);
        }
    }

    fn start_work<F>(&mut self, action: &str, op: F)
    where
        F: FnOnce(&Service, ExecOptions) -> Result<()> + Send + 'static,
    {
        if self.action_in_progress.is_some() {
            self.message = "an action is already running".into();
            return;
        }
        let Some(service) = self.selected_service().cloned() else {
            return;
        };
        let action = action.to_owned();
        let service_name = service.name.clone();
        if self.dry_run {
            self.message = format!("dry-run: {action} {service_name} (no changes made)");
            return;
        }
        let timeout = self.timeout;
        let (tx, rx) = mpsc::channel();
        self.action_in_progress = Some((service_name.clone(), action.clone()));
        self.message = format!("{action} in progress for {service_name}");
        self.action_rx = Some(rx);
        thread::spawn(move || {
            let result = op(&service, ExecOptions::worker(false, timeout))
                .map_err(|error| error.to_string());
            let _ = tx.send(WorkDone::Action(ActionResult {
                service: service_name,
                action,
                result,
            }));
        });
    }

    fn start_action(&mut self, action: &str) {
        let owned = action.to_owned();
        self.start_work(action, move |service, opts| {
            operations::systemctl_action(&owned, service, opts)
        });
    }

    fn start_pull(&mut self) {
        self.start_work("pull", operations::pull_service);
    }

    fn start_update(&mut self) {
        if self.action_in_progress.is_some() {
            self.message = "an action is already running".into();
            return;
        }
        let Some(target) = self.selected_service().cloned() else {
            return;
        };
        if self.dry_run {
            self.message = format!("dry-run: update {} (no changes made)", target.name);
            return;
        }
        let label = target.name.clone();
        let all = self.services.clone();
        let timeout = self.timeout;
        let (tx, rx) = mpsc::channel();
        self.action_in_progress = Some((label.clone(), "update".into()));
        self.message = format!("update in progress for {label}");
        self.action_rx = Some(rx);
        thread::spawn(move || {
            let opts = ExecOptions::worker(false, timeout);
            let target_ref = &target;
            let result = operations::update_services(&all, &[target_ref], opts)
                .map_err(|error| error.to_string());
            let _ = tx.send(WorkDone::Update(UpdateDone { result }));
        });
    }

    fn poll_action(&mut self) {
        let Some(rx) = self.action_rx.as_ref() else {
            return;
        };
        match rx.try_recv() {
            Ok(WorkDone::Action(result)) => {
                self.message = match result.result {
                    Ok(()) => format!("{} completed for {}", result.action, result.service),
                    Err(error) => error,
                };
                self.action_in_progress = None;
                self.action_rx = None;
                self.refresh();
            }
            Ok(WorkDone::Update(done)) => {
                self.message = match done.result {
                    Ok(reports) => reports
                        .iter()
                        .map(|report| format!("{}: {}", report.name, report.describe()))
                        .collect::<Vec<_>>()
                        .join("; "),
                    Err(error) => error,
                };
                self.action_in_progress = None;
                self.action_rx = None;
                self.refresh();
            }
            Err(TryRecvError::Empty) => {}
            Err(TryRecvError::Disconnected) => {
                self.message = "action worker disconnected".into();
                self.action_in_progress = None;
                self.action_rx = None;
            }
        }
    }
}

pub fn run(
    dir: PathBuf,
    dry_run: bool,
    timeout: Duration,
    refresh_interval: Duration,
) -> Result<()> {
    if !io::stdout().is_terminal() {
        bail!("interactive UI requires a terminal; use `svc list` for non-interactive output");
    }
    privilege::warm_credentials()?;
    let mut session = TerminalSession::enter()?;
    let mut app = App::new(dir, dry_run, timeout, refresh_interval)?;
    loop {
        app.poll_action();
        app.poll_logs();
        session.terminal.draw(|frame| draw(frame, &mut app))?;
        if event::poll(Duration::from_millis(200))? {
            match event::read()? {
                Event::Key(key) if key.kind == KeyEventKind::Press => {
                    if app.show_help {
                        match key.code {
                            KeyCode::Char('q') | KeyCode::Esc | KeyCode::Char('?') => {
                                app.show_help = false;
                            }
                            _ => {}
                        }
                    } else if app.filtering {
                        match key.code {
                            KeyCode::Esc => {
                                app.filter.clear();
                                app.filtering = false;
                                app.reselect();
                            }
                            KeyCode::Enter => {
                                app.filtering = false;
                                app.reselect();
                            }
                            KeyCode::Backspace => {
                                app.filter.pop();
                                app.reselect();
                            }
                            KeyCode::Char(c) if !c.is_control() => {
                                app.filter.push(c);
                                app.reselect();
                            }
                            _ => {}
                        }
                    } else {
                        match key.code {
                            KeyCode::Char('q') => break,
                            KeyCode::Esc if app.confirm.is_some() => app.confirm_pending(false),
                            KeyCode::Esc => break,
                            KeyCode::Char('y') | KeyCode::Char('Y') if app.confirm.is_some() => {
                                app.confirm_pending(true)
                            }
                            KeyCode::Char('n') | KeyCode::Char('N') if app.confirm.is_some() => {
                                app.confirm_pending(false)
                            }
                            KeyCode::Tab | KeyCode::BackTab => app.cycle_focus(),
                            KeyCode::Down | KeyCode::Char('j') => match app.focus {
                                Focus::Services => app.move_selection(1),
                                Focus::Logs => app.scroll_logs(1),
                            },
                            KeyCode::Up | KeyCode::Char('k') => match app.focus {
                                Focus::Services => app.move_selection(-1),
                                Focus::Logs => app.scroll_logs(-1),
                            },
                            KeyCode::PageDown if app.focus == Focus::Logs => app.scroll_logs(10),
                            KeyCode::PageUp if app.focus == Focus::Logs => app.scroll_logs(-10),
                            KeyCode::Home if app.focus == Focus::Logs => {
                                app.log_scroll = 0;
                                app.follow_logs = false;
                            }
                            KeyCode::End if app.focus == Focus::Logs => app.scroll_logs_to_latest(),
                            KeyCode::Char('s')
                                if app.focus == Focus::Services && app.confirm.is_none() =>
                            {
                                app.start_action("start")
                            }
                            KeyCode::Char('x')
                                if app.focus == Focus::Services && app.confirm.is_none() =>
                            {
                                app.request_action("stop")
                            }
                            KeyCode::Char('r')
                                if app.focus == Focus::Services && app.confirm.is_none() =>
                            {
                                app.request_action("restart")
                            }
                            KeyCode::Char('U')
                                if app.focus == Focus::Services && app.confirm.is_none() =>
                            {
                                app.request_action("update")
                            }
                            KeyCode::Char('P')
                                if app.focus == Focus::Services && app.confirm.is_none() =>
                            {
                                app.start_pull()
                            }
                            KeyCode::Char('!') if app.confirm.is_none() => {
                                if let Some(service) = app.selected_service().cloned() {
                                    // Leave the alternate screen so the shell
                                    // runs in a real terminal, then re-enter.
                                    drop(session);
                                    let opts = ExecOptions::cli(app.dry_run, app.timeout);
                                    if let Err(error) =
                                        operations::container_shell(&service, "sh", opts)
                                    {
                                        app.message = format!("shell failed: {error:#}");
                                    }
                                    session = TerminalSession::enter()?;
                                    app.refresh();
                                }
                            }
                            KeyCode::Char('/') if app.confirm.is_none() => {
                                app.filtering = true;
                            }
                            KeyCode::Char('?') => {
                                app.show_help = true;
                            }
                            KeyCode::Char(' ') => {
                                app.paused = !app.paused;
                                app.message = if app.paused {
                                    "auto-refresh paused".into()
                                } else {
                                    "auto-refresh resumed".into()
                                };
                            }
                            KeyCode::Char('R') => {
                                app.refresh();
                                app.restart_log_stream();
                            }
                            _ => {}
                        }
                    }
                }
                Event::Mouse(mouse) => match mouse.kind {
                    MouseEventKind::ScrollDown => match app.focus {
                        Focus::Services => app.move_selection(1),
                        Focus::Logs => app.scroll_logs(3),
                    },
                    MouseEventKind::ScrollUp => match app.focus {
                        Focus::Services => app.move_selection(-1),
                        Focus::Logs => app.scroll_logs(-3),
                    },
                    _ => {}
                },
                _ => {}
            }
        }
        if !app.paused
            && app.last_refresh.elapsed() >= app.refresh_interval
            && app.action_in_progress.is_none()
        {
            app.refresh();
        }
    }
    Ok(())
}

fn draw(frame: &mut ratatui::Frame<'_>, app: &mut App) {
    let outer = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(10),
            Constraint::Length(3),
        ])
        .split(frame.area());
    let running = app
        .services
        .iter()
        .filter(|s| s.state == ServiceState::Running)
        .count();
    let attention = app
        .services
        .iter()
        .filter(|s| matches!(s.state, ServiceState::Failed | ServiceState::Unavailable))
        .count();
    frame.render_widget(
        Paragraph::new(Line::from(vec![
            Span::styled(
                " svc ",
                Style::default()
                    .fg(Color::Black)
                    .bg(Color::Cyan)
                    .add_modifier(Modifier::BOLD),
            ),
            Span::raw(format!("  {} services  ", app.services.len())),
            Span::styled(
                format!("{running} running"),
                Style::default().fg(Color::Green),
            ),
            Span::raw("  "),
            Span::styled(
                format!("{attention} attention"),
                Style::default().fg(if attention == 0 {
                    Color::DarkGray
                } else {
                    Color::Red
                }),
            ),
            Span::raw("  "),
            Span::styled(
                if app.paused { "paused" } else { "" },
                Style::default().fg(Color::Yellow),
            ),
        ]))
        .block(Block::default().borders(Borders::ALL)),
        outer[0],
    );
    let middle = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(48), Constraint::Percentage(52)])
        .split(outer[1]);
    draw_services(frame, middle[0], app);
    draw_details(frame, middle[1], app);
    let action = app
        .action_in_progress
        .as_ref()
        .map(|(service, action)| format!("{action} {service}…  "))
        .unwrap_or_default();
    let footer: Line = if let Some(pending) = &app.confirm {
        Line::from(vec![
            Span::styled(
                format!(" {} {}? ", pending.action, pending.service),
                Style::default()
                    .fg(Color::Black)
                    .bg(Color::Yellow)
                    .add_modifier(Modifier::BOLD),
            ),
            Span::raw(" y confirm · n/Esc cancel "),
            Span::styled(&app.message, Style::default().fg(Color::DarkGray)),
        ])
    } else if app.filtering {
        Line::from(vec![
            Span::styled(
                format!(" /{} ", app.filter),
                Style::default()
                    .fg(Color::Black)
                    .bg(Color::Cyan)
                    .add_modifier(Modifier::BOLD),
            ),
            Span::raw(" typing · Enter keep · Esc clear "),
            Span::styled(&app.message, Style::default().fg(Color::DarkGray)),
        ])
    } else {
        Line::from(vec![
            Span::styled(
                " Tab ",
                Style::default()
                    .fg(Color::Cyan)
                    .add_modifier(Modifier::BOLD),
            ),
            Span::raw(
                "focus  j/k move  s start  x stop  r restart  U update  P pull  ! shell  / filter  space pause  ? help  q quit  ",
            ),
            Span::styled(action, Style::default().fg(Color::Yellow)),
            Span::styled(&app.message, Style::default().fg(Color::DarkGray)),
        ])
    };
    frame.render_widget(
        Paragraph::new(footer).block(Block::default().borders(Borders::ALL)),
        outer[2],
    );
    if app.show_help {
        let area = centered_rect(56, 72, frame.area());
        frame.render_widget(Clear, area);
        frame.render_widget(
            Paragraph::new(HELP_TEXT).block(
                Block::default()
                    .title(" Help · q/Esc/? to close ")
                    .borders(Borders::ALL)
                    .border_style(Style::default().fg(Color::Cyan)),
            ),
            area,
        );
    }
}

const HELP_TEXT: &str = "\
j/k, ↑/↓ ......... move selection / scroll logs
Tab ............... switch services/logs focus
PgUp/PgDn,Home,End  scroll logs
s ................. start service
x ................. stop service (confirms)
r ................. restart service (confirms)
U ................. update service image (confirms)
P ................. pull service image
! ................. open shell in container
/ ................. filter services (Enter keep, Esc clear)
space ............. pause/resume auto-refresh
R ................. refresh now
? ................. this help
q ................. quit";

fn centered_rect(percent_x: u16, percent_y: u16, area: Rect) -> Rect {
    let vertical = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Percentage((100 - percent_y) / 2),
            Constraint::Percentage(percent_y),
            Constraint::Percentage((100 - percent_y) / 2),
        ])
        .split(area);
    Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage((100 - percent_x) / 2),
            Constraint::Percentage(percent_x),
            Constraint::Percentage((100 - percent_x) / 2),
        ])
        .split(vertical[1])[1]
}

fn draw_services(frame: &mut ratatui::Frame<'_>, area: Rect, app: &mut App) {
    let visible = app.visible_services();
    let rows = visible.iter().map(|service| {
        Row::new(vec![
            Cell::from(service.name.clone()),
            Cell::from(service.state.label()).style(Style::default().fg(service.state.color())),
            Cell::from(service.startup.clone()),
        ])
    });
    let border_style = if app.focus == Focus::Services {
        Style::default().fg(Color::Cyan)
    } else {
        Style::default()
    };
    let table = Table::new(
        rows,
        [
            Constraint::Percentage(46),
            Constraint::Percentage(34),
            Constraint::Percentage(20),
        ],
    )
    .header(
        Row::new(["SERVICE", "STATE", "MODE"]).style(Style::default().add_modifier(Modifier::BOLD)),
    )
    .row_highlight_style(
        Style::default()
            .bg(Color::DarkGray)
            .add_modifier(Modifier::BOLD),
    )
    .highlight_symbol("▶ ")
    .block(
        Block::default()
            .title(format!(
                " Services {}/{} ",
                visible.len(),
                app.services.len()
            ))
            .borders(Borders::ALL)
            .border_style(border_style),
    );
    frame.render_stateful_widget(table, area, &mut app.table_state);
}

fn draw_details(frame: &mut ratatui::Frame<'_>, area: Rect, app: &mut App) {
    let split = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(11), Constraint::Min(5)])
        .split(area);
    app.log_view_height = split[1].height.saturating_sub(2).max(1);
    if app.follow_logs {
        app.log_scroll = app.max_log_scroll();
    }
    let details = if let Some(service) = app.selected_service() {
        let mut lines = vec![
            Line::from(vec![
                Span::styled(&service.name, Style::default().add_modifier(Modifier::BOLD)),
                Span::raw(format!("  {}", service.state.label())),
            ]),
            Line::from(format!("Container:   {}", service.container_name)),
            Line::from(format!("Unit:        {}", service.unit)),
            Line::from(format!("Load state:  {}", service.load_state)),
            Line::from(format!("Sub-state:   {}", service.sub_state)),
            Line::from(format!("Startup:     {}", service.startup)),
            Line::from(format!(
                "Image:       {}",
                service.image.as_deref().unwrap_or("—")
            )),
            Line::from(format!("Quadlet:     {}", service.file.display())),
        ];
        if let Some(error) = &service.query_error {
            lines.push(Line::from(Span::styled(
                format!("Error:       {error}"),
                Style::default().fg(Color::Red),
            )));
        }
        if let Some(error) = &app.global_error {
            lines.push(Line::from(Span::styled(
                format!("Systemd:     {error}"),
                Style::default().fg(Color::Red),
            )));
        }
        lines
    } else {
        vec![Line::from("No services discovered.")]
    };
    frame.render_widget(
        Paragraph::new(details).block(Block::default().title(" Details ").borders(Borders::ALL)),
        split[0],
    );
    let log_border_style = if app.focus == Focus::Logs {
        Style::default().fg(Color::Cyan)
    } else {
        Style::default()
    };
    frame.render_widget(
        Paragraph::new(app.logs.as_str())
            .scroll((app.log_scroll, 0))
            .wrap(Wrap { trim: false })
            .block(
                Block::default()
                    .title(format!(
                        " Recent logs · line {}{} ",
                        app.log_scroll.saturating_add(1),
                        if app.follow_logs { " · following" } else { "" }
                    ))
                    .borders(Borders::ALL)
                    .border_style(log_border_style),
            ),
        split[1],
    );
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn service(name: &str) -> Service {
        Service::new(
            name.into(),
            name.into(),
            None,
            None,
            PathBuf::from(format!("{name}.container")),
        )
    }

    fn test_app(services: Vec<Service>, selected: Option<&str>) -> App {
        let mut app = App {
            dir: PathBuf::new(),
            dry_run: true,
            timeout: Duration::from_secs(5),
            refresh_interval: Duration::from_secs(5),
            services,
            selected_name: selected.map(str::to_owned),
            table_state: TableState::default(),
            focus: Focus::Services,
            logs: String::new(),
            log_stream: None,
            log_scroll: 0,
            log_view_height: 10,
            follow_logs: true,
            message: String::new(),
            confirm: None,
            filter: String::new(),
            filtering: false,
            show_help: false,
            paused: false,
            global_error: None,
            action_rx: None,
            action_in_progress: None,
            last_refresh: Instant::now(),
        };
        app.sync_selection();
        app
    }

    #[test]
    fn selection_survives_reordering_by_name() {
        let mut app = test_app(vec![service("a"), service("b")], Some("b"));
        app.services = vec![service("b"), service("c")];
        app.sync_selection();
        assert_eq!(app.selected_name.as_deref(), Some("b"));
        assert_eq!(app.table_state.selected(), Some(0));
    }

    #[test]
    fn tab_cycles_focus_and_logs_scroll() {
        let mut app = test_app(vec![service("a")], Some("a"));
        app.logs = (1..=30)
            .map(|line| format!("line {line}"))
            .collect::<Vec<_>>()
            .join("\n");
        app.follow_logs = false;
        app.cycle_focus();
        assert_eq!(app.focus, Focus::Logs);
        app.scroll_logs(10);
        assert_eq!(app.log_scroll, 10);
        assert!(!app.follow_logs);
        app.scroll_logs(-3);
        assert_eq!(app.log_scroll, 7);
        app.cycle_focus();
        assert_eq!(app.focus, Focus::Services);
    }

    #[test]
    fn filter_narrows_visible_services() {
        let mut app = test_app(
            vec![service("forgejo"), service("postgres"), service("caddy")],
            Some("forgejo"),
        );
        assert_eq!(app.visible_services().len(), 3);
        app.filter = "post".into();
        app.reselect();
        assert_eq!(app.selected_name.as_deref(), Some("postgres"));
        assert_eq!(app.visible_services().len(), 1);
        app.filter = "zzz".into();
        app.reselect();
        assert_eq!(app.selected_name, None);
        assert_eq!(app.table_state.selected(), None);
    }

    #[test]
    fn filter_matches_image_and_state_case_insensitively() {
        let mut imaged = service("web");
        imaged.image = Some("ghcr.io/Example/App:1".into());
        let app = test_app(vec![imaged], Some("web"));
        assert!(app.matches_filter(&app.services[0]));
        let mut queried = app;
        queried.filter = "example".into();
        assert!(queried.matches_filter(&queried.services[0]));
        queried.filter = "RUNNING".into();
        // State label is "○ stopped"; RUNNING must not match.
        assert!(!queried.matches_filter(&queried.services[0]));
    }

    #[test]
    fn stop_requires_confirmation_and_dry_run_skips_spawn() {
        let mut app = test_app(vec![service("a")], Some("a"));
        app.request_action("stop");
        assert!(app.confirm.is_some());
        assert_eq!(app.action_in_progress, None);
        app.confirm_pending(true);
        assert!(app.confirm.is_none());
        assert!(app.action_in_progress.is_none());
        assert!(app.message.contains("dry-run"));
    }

    #[test]
    fn start_runs_without_confirmation() {
        let mut app = test_app(vec![service("a")], Some("a"));
        app.request_action("start");
        assert!(app.confirm.is_none());
        assert!(app.message.contains("dry-run"));
    }

    #[test]
    fn log_buffer_is_capped() {
        let mut logs = String::new();
        for index in 0..LOG_LINE_CAP + 100 {
            push_log_line(&mut logs, &format!("line {index}"));
        }
        assert_eq!(logs.lines().count(), LOG_LINE_CAP);
        assert!(logs.lines().next().unwrap().starts_with("line 100"));
    }
}
