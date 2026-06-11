#!/usr/bin/env python3
"""
Claude Code Hook Handler — dotclaude port
=========================================

Plays sounds for the 27 Claude Code hook events. Adapted from
shanraisshan/claude-code-best-practice with three additions:

  - SOUNDS_DISABLED / CLAUDE_QUIET env-var bail (CI, SSH, quiet hours).
  - --dry-run flag for bootstrap verification.
  - User-scope path resolution: when not running under CLAUDE_PROJECT_DIR,
    falls back to ~/.claude.

Hook events arrive as JSON on stdin (the canonical contract). The dispatcher
exits 0 even on error so it never blocks Claude's work.

Special handling:
  - git commit → pretooluse-git-committing sound
  - --agent=<name> → 6 agent-specific sound folders

References:
  - https://docs.claude.com/en/docs/claude-code/hooks
"""

import argparse
import json
import os
import platform
import re
import subprocess
import sys
import time
from pathlib import Path

try:
    import winsound
except ImportError:
    winsound = None

# ===== HOOK EVENT TO SOUND FOLDER MAPPING =====

HOOK_SOUND_MAP = {
    "PreToolUse": "pretooluse",
    "PermissionRequest": "permissionrequest",
    "PostToolUse": "posttooluse",
    "PostToolUseFailure": "posttoolusefailure",
    "UserPromptSubmit": "userpromptsubmit",
    "Notification": "notification",
    "Stop": "stop",
    "SubagentStart": "subagentstart",
    "SubagentStop": "subagentstop",
    "PreCompact": "precompact",
    "PostCompact": "postcompact",
    "SessionStart": "sessionstart",
    "SessionEnd": "sessionend",
    "Setup": "setup",
    "TeammateIdle": "teammateidle",
    "TaskCreated": "taskcreated",
    "TaskCompleted": "taskcompleted",
    "ConfigChange": "configchange",
    "WorktreeCreate": "worktreecreate",
    "WorktreeRemove": "worktreeremove",
    "InstructionsLoaded": "instructionsloaded",
    "Elicitation": "elicitation",
    "ElicitationResult": "elicitationresult",
    "StopFailure": "stopfailure",
    "CwdChanged": "cwdchanged",
    "FileChanged": "filechanged",
    "PermissionDenied": "permissiondenied",
}

AGENT_HOOK_SOUND_MAP = {
    "PreToolUse": "agent_pretooluse",
    "PostToolUse": "agent_posttooluse",
    "PermissionRequest": "agent_permissionrequest",
    "PostToolUseFailure": "agent_posttoolusefailure",
    "Stop": "agent_stop",
    "SubagentStop": "agent_subagentstop",
}

BASH_PATTERNS = [
    (r"git commit", "pretooluse-git-committing"),
]


# ===== AUDIO PLAYER DETECTION =====

def get_audio_player():
    """Detect the audio player for the current platform; returns argv prefix or None."""
    system = platform.system()
    if system == "Darwin":
        return ["afplay"]
    if system == "Linux":
        for player in (["paplay"], ["aplay"], ["ffplay", "-nodisp", "-autoexit"], ["mpg123", "-q"]):
            try:
                subprocess.run(
                    ["which", player[0]],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True
                )
                return player
            except (subprocess.CalledProcessError, FileNotFoundError):
                continue
        return None
    if system == "Windows":
        return ["WINDOWS"]
    return None


def play_sound(sound_name):
    """Play sounds/<folder>/<sound_name>.{wav,mp3}. Folder = sound_name.split('-')[0]."""
    if "/" in sound_name or "\\" in sound_name or ".." in sound_name:
        print(f"Invalid sound name: {sound_name}", file=sys.stderr)
        return False

    audio_player = get_audio_player()
    if not audio_player:
        return False

    script_dir = Path(__file__).parent
    hooks_dir = script_dir.parent
    folder_name = sound_name.split("-")[0]
    sounds_dir = hooks_dir / "sounds" / folder_name

    is_windows = audio_player[0] == "WINDOWS"
    extensions = [".wav"] if is_windows else [".wav", ".mp3"]

    for extension in extensions:
        file_path = sounds_dir / f"{sound_name}{extension}"
        if not file_path.exists():
            continue
        try:
            if is_windows:
                if winsound:
                    winsound.PlaySound(str(file_path), winsound.SND_FILENAME | winsound.SND_NODEFAULT)
                    return True
                return False
            subprocess.Popen(
                audio_player + [str(file_path)],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
            return True
        except (FileNotFoundError, OSError) as e:
            print(f"Error playing {file_path.name}: {e}", file=sys.stderr)
            return False
        except Exception as e:
            print(f"Error playing {file_path.name}: {e}", file=sys.stderr)
            return False

    return False


# ===== CONFIG (per-hook toggles + logging) =====

def _load_configs():
    """Load hooks-config.local.json (precedence) and hooks-config.json (fallback)."""
    script_dir = Path(__file__).parent
    hooks_dir = script_dir.parent
    config_dir = hooks_dir / "config"
    out = {}
    for name, key in (("hooks-config.local.json", "local"), ("hooks-config.json", "default")):
        p = config_dir / name
        if not p.exists():
            out[key] = None
            continue
        try:
            with open(p, "r", encoding="utf-8") as f:
                out[key] = json.load(f)
        except Exception as e:
            print(f"Error reading {p.name}: {e}", file=sys.stderr)
            out[key] = None
    return out


def is_hook_disabled(event_name):
    """Check disable<EventName>Hook in local override → default. Default: enabled."""
    try:
        cfg = _load_configs()
        key = f"disable{event_name}Hook"
        if cfg["local"] is not None and key in cfg["local"]:
            return cfg["local"][key]
        if cfg["default"] is not None and key in cfg["default"]:
            return cfg["default"][key]
        return False
    except Exception as e:
        print(f"Error in is_hook_disabled: {e}", file=sys.stderr)
        return False


def is_logging_disabled():
    try:
        cfg = _load_configs()
        if cfg["local"] is not None and "disableLogging" in cfg["local"]:
            return cfg["local"]["disableLogging"]
        if cfg["default"] is not None and "disableLogging" in cfg["default"]:
            return cfg["default"]["disableLogging"]
        return False
    except Exception as e:
        print(f"Error in is_logging_disabled: {e}", file=sys.stderr)
        return False


def log_hook_data(hook_data, agent_name=None):
    """Append hook event to hooks/logs/hooks-log.jsonl. PII-light by design."""
    if is_logging_disabled():
        return
    try:
        script_dir = Path(__file__).parent
        hooks_dir = script_dir.parent
        logs_dir = hooks_dir / "logs"
        logs_dir.mkdir(parents=True, exist_ok=True)
        entry = hook_data.copy()
        entry.pop("transcript_path", None)
        entry.pop("cwd", None)
        if agent_name:
            entry["invoked_by_agent"] = agent_name
        log_path = logs_dir / "hooks-log.jsonl"
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except Exception as e:
        print(f"Failed to log hook_data: {e}", file=sys.stderr)


# ===== SOUND RESOLUTION =====

def detect_bash_command_sound(command):
    if not command:
        return None
    for pattern, sound_name in BASH_PATTERNS:
        if re.search(pattern, command.strip()):
            return sound_name
    return None


def get_sound_name(hook_data, agent_name=None):
    event_name = hook_data.get("hook_event_name", "")
    tool_name = hook_data.get("tool_name", "")

    if agent_name:
        return AGENT_HOOK_SOUND_MAP.get(event_name)

    if event_name == "PreToolUse" and tool_name == "Bash":
        command = hook_data.get("tool_input", {}).get("command", "")
        special = detect_bash_command_sound(command)
        if special:
            return special

    return HOOK_SOUND_MAP.get(event_name)


# ===== CLI =====

def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Claude Code Hook Handler — plays sounds for hook events.",
        epilog="Set SOUNDS_DISABLED=1 or CLAUDE_QUIET=1 to silence without disabling each hook.",
    )
    parser.add_argument("event_name_arg", nargs="?", default=None,
                        help="Optional positional event name (also takes from stdin JSON).")
    parser.add_argument("--agent", type=str, default=None,
                        help="Agent name for agent-specific sounds.")
    parser.add_argument("--dry-run", action="store_true",
                        help="Verify dispatcher loads + sound tree is reachable; exit without playing.")
    return parser.parse_args()


def is_quiet():
    """Honor SOUNDS_DISABLED or CLAUDE_QUIET env vars (CI, SSH, quiet hours)."""
    for var in ("SOUNDS_DISABLED", "CLAUDE_QUIET"):
        val = os.environ.get(var, "").strip().lower()
        if val in ("1", "true", "yes", "on"):
            return True
    return False


def dry_run_check():
    """Bootstrap-time sanity check: dispatcher imports, sound tree exists."""
    hooks_dir = Path(__file__).parent.parent
    sounds_dir = hooks_dir / "sounds"
    if not sounds_dir.exists():
        print(f"FAIL: sound tree missing at {sounds_dir}", file=sys.stderr)
        sys.exit(1)
    expected = {"pretooluse", "posttooluse", "sessionstart", "stop", "agent_pretooluse"}
    missing = [f for f in expected if not (sounds_dir / f).exists()]
    if missing:
        print(f"FAIL: missing sound folders: {missing}", file=sys.stderr)
        sys.exit(1)
    print("OK: dispatcher imports, sound tree present.")
    sys.exit(0)


def maybe_launch_self_update():
    """On SessionStart, kick off scripts/self-update.sh detached and throttled.

    The check here is read-only — it only avoids forking bash on every session.
    The script itself is the throttle authority and claims the slot on start.
    Never raises: a self-update failure must not block SessionStart.
    """
    try:
        if is_hook_disabled("SelfUpdate"):
            return
        dotclaude = Path(__file__).parent.parent.parent
        throttle = dotclaude / ".last-self-update"
        try:
            interval_h = float(os.environ.get("SELF_UPDATE_INTERVAL_HOURS", "24"))
        except ValueError:
            interval_h = 24.0
        force = os.environ.get("SELF_UPDATE_FORCE", "").strip().lower() not in ("", "0", "false", "no", "off")
        if not force and throttle.exists():
            if (time.time() - throttle.stat().st_mtime) < interval_h * 3600:
                return
        script = dotclaude / "scripts" / "self-update.sh"
        if not script.exists():
            return
        subprocess.Popen(
            ["bash", str(script)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except Exception as e:
        print(f"self-update launch skipped: {e}", file=sys.stderr)


def main():
    try:
        args = parse_arguments()

        if args.dry_run:
            dry_run_check()

        # Self-update (SessionStart only) — independent of sound/quiet settings.
        if args.event_name_arg == "SessionStart" and not args.agent:
            maybe_launch_self_update()

        # Quiet-mode bail BEFORE any logging or sound work
        if is_quiet():
            sys.exit(0)

        stdin_content = sys.stdin.read().strip() if not sys.stdin.isatty() else ""
        if not stdin_content:
            sys.exit(0)

        input_data = json.loads(stdin_content)

        # Allow positional arg to override the event name (useful when wired via settings.json)
        if args.event_name_arg and not input_data.get("hook_event_name"):
            input_data["hook_event_name"] = args.event_name_arg

        log_hook_data(input_data, agent_name=args.agent)

        event_name = input_data.get("hook_event_name", "")
        if not args.agent and is_hook_disabled(event_name):
            sys.exit(0)

        sound_name = get_sound_name(input_data, agent_name=args.agent)
        if sound_name:
            play_sound(sound_name)

        sys.exit(0)

    except json.JSONDecodeError as e:
        print(f"Error parsing JSON input: {e}", file=sys.stderr)
        sys.exit(0)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(0)


if __name__ == "__main__":
    main()
