use assert_cmd::Command;
use predicates::prelude::*;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::PathBuf;

const SYSTEMCTL_STUB: &str = r#"#!/bin/sh
if [ "$1" = "show" ]; then
  shift
  for unit in "$@"; do
    case "$unit" in -*|*=*) continue ;; esac
    case "$unit" in
      db.service) active=failed; sub=failed ;;
      *) active=active; sub=running ;;
    esac
    printf 'Id=%s\nActiveState=%s\nSubState=%s\nUnitFileState=generated\nLoadState=loaded\n\n' "$unit" "$active" "$sub"
  done
  exit 0
fi
if [ "$1" = "status" ]; then echo "stub status for $2"; exit 3; fi
echo "systemctl $*" >> "$STUB_LOG"
if [ "$STUB_FAIL_ALL" = "1" ]; then echo "stub: failing $2" >&2; exit 1; fi
if [ -n "$STUB_FAIL" ] && [ "$2" = "$STUB_FAIL" ]; then echo "stub: failing $2" >&2; exit 1; fi
exit 0
"#;

const PODMAN_STUB: &str = r#"#!/bin/sh
echo "podman $*" >> "$STUB_LOG"
case "$1" in
  auto-update)
    printf 'web\t%s\ndb\t%s\n' "${WEB_UPDATE:-false}" "${DB_UPDATE:-false}"
    ;;
  inspect)
    echo "sha256:$4"
    ;;
esac
exit 0
"#;

const SUDO_STUB: &str = r#"#!/bin/sh
if [ "$1" = "-n" ]; then shift; fi
exec "$@"
"#;

struct Harness {
    _dir: tempfile::TempDir,
    quadlet: PathBuf,
    bin: PathBuf,
    log: PathBuf,
}

fn write_stub(dir: &std::path::Path, name: &str, content: &str) {
    let path = dir.join(name);
    fs::write(&path, content).unwrap();
    fs::set_permissions(&path, fs::Permissions::from_mode(0o755)).unwrap();
}

fn harness() -> Harness {
    let dir = tempfile::tempdir().unwrap();
    let quadlet = dir.path().join("quadlets");
    fs::create_dir(&quadlet).unwrap();
    fs::write(
        quadlet.join("web.container"),
        "[Unit]\nDescription=Web\n[Container]\nImage=example/web:1\n",
    )
    .unwrap();
    fs::write(
        quadlet.join("db.container"),
        "[Container]\nImage=example/db:1\n",
    )
    .unwrap();
    let bin = dir.path().join("bin");
    fs::create_dir(&bin).unwrap();
    write_stub(&bin, "systemctl", SYSTEMCTL_STUB);
    write_stub(&bin, "podman", PODMAN_STUB);
    write_stub(&bin, "sudo", SUDO_STUB);
    Harness {
        log: dir.path().join("calls.log"),
        _dir: dir,
        quadlet,
        bin,
    }
}

fn svc(harness: &Harness) -> Command {
    let mut cmd = Command::cargo_bin("svc").unwrap();
    let path = format!(
        "{}:{}",
        harness.bin.display(),
        std::env::var_os("PATH").unwrap().to_str().unwrap()
    );
    cmd.env("PATH", path)
        .env("SVC_NO_SUDO", "1")
        .env("STUB_LOG", &harness.log)
        .arg("--quadlet-dir")
        .arg(&harness.quadlet);
    cmd
}

fn stub_log(harness: &Harness) -> String {
    fs::read_to_string(&harness.log).unwrap_or_default()
}

#[test]
fn list_shows_discovered_services() {
    let harness = harness();
    svc(&harness)
        .arg("list")
        .assert()
        .success()
        .stdout(predicate::str::contains("web"))
        .stdout(predicate::str::contains("db"));
}

#[test]
fn list_failed_only_filters_to_attention() {
    let harness = harness();
    svc(&harness)
        .arg("list")
        .arg("--failed-only")
        .assert()
        .success()
        .stdout(predicate::str::contains("db"))
        .stdout(predicate::str::contains("web").not());
}

#[test]
fn json_list_is_machine_readable() {
    let harness = harness();
    let assert = svc(&harness).arg("--json").arg("list").assert().success();
    let output = String::from_utf8(assert.get_output().stdout.clone()).unwrap();
    let parsed: serde_json::Value = serde_json::from_str(&output).unwrap();
    assert_eq!(parsed.as_array().unwrap().len(), 2);
}

#[test]
fn start_partial_failure_exits_two() {
    let harness = harness();
    svc(&harness)
        .arg("start")
        .arg("web")
        .arg("db")
        .env("STUB_FAIL", "db.service")
        .assert()
        .code(2)
        .stderr(predicate::str::contains("db"));
}

#[test]
fn start_total_failure_exits_one() {
    let harness = harness();
    svc(&harness)
        .arg("start")
        .arg("web")
        .arg("db")
        .env("STUB_FAIL_ALL", "1")
        .assert()
        .code(1);
}

#[test]
fn unknown_service_is_an_error() {
    let harness = harness();
    svc(&harness)
        .arg("start")
        .arg("nope")
        .assert()
        .code(1)
        .stderr(predicate::str::contains("unknown service"));
}

#[test]
fn update_dry_run_runs_reads_but_no_mutations() {
    let harness = harness();
    svc(&harness)
        .arg("--dry-run")
        .arg("update")
        .arg("web")
        .arg("--yes")
        .env("WEB_UPDATE", "pending")
        .assert()
        .success()
        .stdout(predicate::str::contains("dry-run"));
    let log = stub_log(&harness);
    assert!(log.contains("auto-update"), "reads run for real:\n{log}");
    assert!(log.contains("inspect"), "reads run for real:\n{log}");
    assert!(!log.contains("pull"), "no mutations in dry-run:\n{log}");
    assert!(
        !log.contains("systemctl stop"),
        "no mutations in dry-run:\n{log}"
    );
}

#[test]
fn outdated_reports_pending_with_exit_two() {
    let harness = harness();
    svc(&harness)
        .arg("outdated")
        .env("WEB_UPDATE", "pending")
        .assert()
        .code(2)
        .stdout(predicate::str::contains("update available"))
        .stdout(predicate::str::contains("up to date"));
}

#[test]
fn outdated_clean_exits_zero() {
    let harness = harness();
    svc(&harness)
        .arg("outdated")
        .assert()
        .success()
        .stdout(predicate::str::contains(
            "0 service(s) with updates available",
        ));
}

#[test]
fn daemon_reload_dry_run_prints_only() {
    let harness = harness();
    svc(&harness)
        .arg("--dry-run")
        .arg("daemon-reload")
        .assert()
        .success()
        .stdout(predicate::str::contains("dry-run"));
    assert!(!stub_log(&harness).contains("daemon-reload"));
}

#[test]
fn exec_dry_run_prints_only() {
    let harness = harness();
    svc(&harness)
        .arg("--dry-run")
        .arg("exec")
        .arg("web")
        .arg("--")
        .arg("ls")
        .arg("/")
        .assert()
        .success()
        .stdout(predicate::str::contains("dry-run"));
}

#[test]
fn status_accepts_inactive_exit_code() {
    let harness = harness();
    svc(&harness)
        .arg("status")
        .arg("web")
        .assert()
        .success()
        .stdout(predicate::str::contains("stub status"));
}

#[test]
fn man_prints_roff() {
    let harness = harness();
    svc(&harness)
        .arg("man")
        .assert()
        .success()
        .stdout(predicate::str::contains(".TH"));
}

#[test]
fn completions_bash_mentions_svc() {
    let harness = harness();
    svc(&harness)
        .arg("completions")
        .arg("bash")
        .assert()
        .success()
        .stdout(predicate::str::contains("svc"));
}
