use std::{
    io::{self, IsTerminal},
    path::PathBuf,
    sync::mpsc::{self, Receiver, TryRecvError},
    thread,
    time::{Duration, Instant},
};

use anyhow::{Result, bail};
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
    widgets::{Block, Borders, Cell, Paragraph, Row, Table, TableState, Wrap},
};

use crate::{
    model::{Service, ServiceState},
    operations, privilege, quadlet, systemd,
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

pub struct App {
    dir: PathBuf,
    services: Vec<Service>,
    selected_name: Option<String>,
    table_state: TableState,
    focus: Focus,
    logs: String,
    log_scroll: u16,
    log_view_height: u16,
    follow_logs: bool,
    message: String,
    global_error: Option<String>,
    action_rx: Option<Receiver<ActionResult>>,
    action_in_progress: Option<(String, String)>,
    last_refresh: Instant,
}

impl App {
    pub fn new(dir: PathBuf) -> Result<Self> {
        let mut app = Self {
            dir,
            services: Vec::new(),
            selected_name: None,
            table_state: TableState::default(),
            focus: Focus::Services,
            logs: String::new(),
            log_scroll: 0,
            log_view_height: 1,
            follow_logs: true,
            message: String::new(),
            global_error: None,
            action_rx: None,
            action_in_progress: None,
            last_refresh: Instant::now(),
        };
        app.refresh();
        Ok(app)
    }

    fn selected_index(&self) -> Option<usize> {
        self.selected_name.as_ref().and_then(|name| {
            self.services
                .iter()
                .position(|service| &service.name == name)
        })
    }

    fn sync_selection(&mut self) {
        if self.services.is_empty() {
            self.selected_name = None;
            self.table_state.select(None);
            return;
        }
        let index = self.selected_index().unwrap_or(0);
        self.selected_name = Some(self.services[index].name.clone());
        self.table_state.select(Some(index));
    }

    fn selected_service(&self) -> Option<&Service> {
        self.selected_index()
            .and_then(|index| self.services.get(index))
    }

    fn refresh(&mut self) {
        let previous = self.selected_name.clone();
        match quadlet::discover(&self.dir) {
            Ok(mut services) => {
                self.global_error = systemd::refresh_services(&mut services)
                    .err()
                    .map(|error| error.to_string());
                self.services = services;
                self.selected_name = previous;
                self.sync_selection();
                self.refresh_logs();
                self.last_refresh = Instant::now();
            }
            Err(error) => self.global_error = Some(error.to_string()),
        }
    }

    fn refresh_logs(&mut self) {
        self.logs = self
            .selected_service()
            .map(|service| operations::tail_logs(service, 200))
            .unwrap_or_else(|| "No service selected.".into());
        if self.follow_logs {
            self.scroll_logs_to_latest();
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
        if self.services.is_empty() {
            return;
        }
        let current = self.selected_index().unwrap_or(0) as isize;
        let next = (current + delta).rem_euclid(self.services.len() as isize) as usize;
        self.selected_name = Some(self.services[next].name.clone());
        self.sync_selection();
        self.follow_logs = true;
        self.refresh_logs();
    }

    fn start_action(&mut self, action: &str) {
        if self.action_in_progress.is_some() {
            self.message = "an action is already running".into();
            return;
        }
        let Some(service) = self.selected_service().cloned() else {
            return;
        };
        let action = action.to_owned();
        let service_name = service.name.clone();
        let (tx, rx) = mpsc::channel();
        self.action_in_progress = Some((service_name.clone(), action.clone()));
        self.message = format!("{action} in progress for {service_name}");
        self.action_rx = Some(rx);
        thread::spawn(move || {
            let result = operations::systemctl_action(&action, &service, true)
                .map_err(|error| error.to_string());
            let _ = tx.send(ActionResult {
                service: service_name,
                action,
                result,
            });
        });
    }

    fn poll_action(&mut self) {
        let Some(rx) = self.action_rx.as_ref() else {
            return;
        };
        match rx.try_recv() {
            Ok(result) => {
                self.message = match result.result {
                    Ok(()) => format!("{} completed for {}", result.action, result.service),
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

pub fn run(dir: PathBuf) -> Result<()> {
    if !io::stdout().is_terminal() {
        bail!("interactive UI requires a terminal; use `svc list` for non-interactive output");
    }
    privilege::warm_credentials()?;
    let mut session = TerminalSession::enter()?;
    let mut app = App::new(dir)?;
    loop {
        app.poll_action();
        session.terminal.draw(|frame| draw(frame, &mut app))?;
        if event::poll(Duration::from_millis(200))? {
            match event::read()? {
                Event::Key(key) if key.kind == KeyEventKind::Press => match key.code {
                    KeyCode::Char('q') | KeyCode::Esc => break,
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
                    KeyCode::Char('s') if app.focus == Focus::Services => app.start_action("start"),
                    KeyCode::Char('x') if app.focus == Focus::Services => app.start_action("stop"),
                    KeyCode::Char('r') if app.focus == Focus::Services => {
                        app.start_action("restart")
                    }
                    KeyCode::Char('R') => app.refresh(),
                    _ => {}
                },
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
        if app.last_refresh.elapsed() >= Duration::from_secs(5) && app.action_in_progress.is_none()
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
    frame.render_widget(
        Paragraph::new(Line::from(vec![
            Span::styled(
                " Tab ",
                Style::default()
                    .fg(Color::Cyan)
                    .add_modifier(Modifier::BOLD),
            ),
            Span::raw("focus  ↑/↓ or j/k move/scroll  PgUp/PgDn logs  s start  x stop  r restart  R refresh  q quit  "),
            Span::styled(action, Style::default().fg(Color::Yellow)),
            Span::styled(&app.message, Style::default().fg(Color::DarkGray)),
        ]))
        .block(Block::default().borders(Borders::ALL)),
        outer[2],
    );
}

fn draw_services(frame: &mut ratatui::Frame<'_>, area: Rect, app: &mut App) {
    let rows = app.services.iter().map(|service| {
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
            .title(" Services ")
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

    #[test]
    fn selection_survives_reordering_by_name() {
        let mut app = App {
            dir: PathBuf::new(),
            services: vec![service("a"), service("b")],
            selected_name: Some("b".into()),
            table_state: TableState::default(),
            focus: Focus::Services,
            logs: String::new(),
            log_scroll: 0,
            log_view_height: 10,
            follow_logs: true,
            message: String::new(),
            global_error: None,
            action_rx: None,
            action_in_progress: None,
            last_refresh: Instant::now(),
        };
        app.services = vec![service("b"), service("c")];
        app.sync_selection();
        assert_eq!(app.selected_name.as_deref(), Some("b"));
        assert_eq!(app.table_state.selected(), Some(0));
    }

    #[test]
    fn tab_cycles_focus_and_logs_scroll() {
        let mut app = App {
            dir: PathBuf::new(),
            services: vec![service("a")],
            selected_name: Some("a".into()),
            table_state: TableState::default(),
            focus: Focus::Services,
            logs: (1..=30)
                .map(|line| format!("line {line}"))
                .collect::<Vec<_>>()
                .join("\n"),
            log_scroll: 0,
            log_view_height: 10,
            follow_logs: false,
            message: String::new(),
            global_error: None,
            action_rx: None,
            action_in_progress: None,
            last_refresh: Instant::now(),
        };
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
}
