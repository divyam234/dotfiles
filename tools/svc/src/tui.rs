use std::{
    io::{self, IsTerminal},
    path::PathBuf,
    sync::mpsc::{self, Receiver, TryRecvError},
    thread,
    time::{Duration, Instant},
};

use anyhow::{Result, bail};
use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
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
        execute!(stdout, EnterAlternateScreen)?;
        Ok(Self {
            terminal: Terminal::new(CrosstermBackend::new(stdout))?,
        })
    }
}

impl Drop for TerminalSession {
    fn drop(&mut self) {
        let _ = disable_raw_mode();
        let _ = execute!(self.terminal.backend_mut(), LeaveAlternateScreen);
        let _ = self.terminal.show_cursor();
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
    logs: String,
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
            logs: String::new(),
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
            .map(|service| operations::tail_logs(service, 80))
            .unwrap_or_else(|| "No service selected.".into());
    }

    fn move_selection(&mut self, delta: isize) {
        if self.services.is_empty() {
            return;
        }
        let current = self.selected_index().unwrap_or(0) as isize;
        let next = (current + delta).rem_euclid(self.services.len() as isize) as usize;
        self.selected_name = Some(self.services[next].name.clone());
        self.sync_selection();
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
        if event::poll(Duration::from_millis(200))?
            && let Event::Key(key) = event::read()?
            && key.kind == KeyEventKind::Press
        {
            match key.code {
                KeyCode::Char('q') | KeyCode::Esc => break,
                KeyCode::Down | KeyCode::Char('j') => app.move_selection(1),
                KeyCode::Up | KeyCode::Char('k') => app.move_selection(-1),
                KeyCode::Char('s') => app.start_action("start"),
                KeyCode::Char('x') => app.start_action("stop"),
                KeyCode::Char('r') => app.start_action("restart"),
                KeyCode::Char('R') => app.refresh(),
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
                " ↑/↓ ",
                Style::default()
                    .fg(Color::Cyan)
                    .add_modifier(Modifier::BOLD),
            ),
            Span::raw("select  s start  x stop  r restart  R refresh  q quit  "),
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
    .block(Block::default().title(" Services ").borders(Borders::ALL));
    frame.render_stateful_widget(table, area, &mut app.table_state);
}

fn draw_details(frame: &mut ratatui::Frame<'_>, area: Rect, app: &App) {
    let split = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(11), Constraint::Min(5)])
        .split(area);
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
    frame.render_widget(
        Paragraph::new(app.logs.as_str())
            .wrap(Wrap { trim: false })
            .block(
                Block::default()
                    .title(" Recent logs ")
                    .borders(Borders::ALL),
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
            logs: String::new(),
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
}
