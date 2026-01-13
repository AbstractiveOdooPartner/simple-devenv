#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "textual>=0.47.0",
# ]
# ///
"""Textual TUI for simple-devenv - Odoo development environment setup."""

import os
import subprocess
from pathlib import Path

from textual import on
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Container, Horizontal, Vertical, VerticalScroll
from textual.screen import ModalScreen
from textual.widgets import (
    Button,
    Checkbox,
    DirectoryTree,
    Footer,
    Header,
    Input,
    Label,
    Log,
    OptionList,
    Select,
    Static,
)
from textual.widgets.option_list import Option


class FilteredDirectoryTree(DirectoryTree):
    """DirectoryTree that filters out hidden folders."""

    def filter_paths(self, paths: list[Path]) -> list[Path]:
        return [p for p in paths if not p.name.startswith(".")]


class DirectoryPickerScreen(ModalScreen[Path | None]):
    """Modal screen for picking a directory."""

    BINDINGS = [
        Binding("escape", "cancel", "Cancel"),
    ]

    CSS = """
    DirectoryPickerScreen {
        align: center middle;
    }

    DirectoryPickerScreen > Container {
        width: 80%;
        height: 80%;
        border: thick $accent;
        background: $surface;
        padding: 1 2;
    }

    DirectoryPickerScreen DirectoryTree {
        height: 1fr;
        border: solid $primary;
        margin: 1 0;
    }

    DirectoryPickerScreen #selected-path {
        height: 3;
        padding: 1;
        background: $primary-background;
        margin-bottom: 1;
    }

    DirectoryPickerScreen #new-folder-row {
        height: auto;
        margin-bottom: 1;
    }

    DirectoryPickerScreen #new-folder-input {
        width: 1fr;
    }

    DirectoryPickerScreen #button-row {
        height: auto;
        align: center middle;
    }

    DirectoryPickerScreen Button {
        margin: 0 1;
    }
    """

    def __init__(self, start_path: Path | None = None) -> None:
        super().__init__()
        self.start_path = start_path or Path.home()
        self.selected_path: Path | None = None

    def compose(self) -> ComposeResult:
        with Container():
            yield Label("Select Target Directory", id="title")
            yield Static(f"Current: {self.start_path}", id="selected-path")
            yield FilteredDirectoryTree(str(self.start_path), id="dir-tree")
            with Horizontal(id="new-folder-row"):
                yield Input(placeholder="New folder name", id="new-folder-input")
                yield Button("Create Folder", id="create-folder-btn")
            with Horizontal(id="button-row"):
                yield Button("Select", variant="primary", id="select-btn")
                yield Button("Cancel", variant="default", id="cancel-btn")

    def on_mount(self) -> None:
        tree = self.query_one(FilteredDirectoryTree)
        tree.show_root = True
        tree.show_guides = True

    @on(DirectoryTree.DirectorySelected)
    def on_directory_selected(self, event: DirectoryTree.DirectorySelected) -> None:
        self.selected_path = event.path
        self.query_one("#selected-path", Static).update(f"Selected: {event.path}")

    @on(Button.Pressed, "#create-folder-btn")
    def on_create_folder(self) -> None:
        folder_name = self.query_one("#new-folder-input", Input).value.strip()
        if not folder_name:
            return

        parent = self.selected_path or self.start_path
        new_path = parent / folder_name

        try:
            new_path.mkdir(parents=True, exist_ok=True)
            self.selected_path = new_path
            self.query_one("#selected-path", Static).update(f"Created & Selected: {new_path}")
            self.query_one("#new-folder-input", Input).value = ""
            # Reload the tree
            tree = self.query_one(FilteredDirectoryTree)
            tree.reload()
        except OSError as e:
            self.query_one("#selected-path", Static).update(f"Error: {e}")

    @on(Button.Pressed, "#select-btn")
    def on_select(self) -> None:
        # Use selected path or the start path if nothing was selected
        result = self.selected_path or self.start_path
        self.dismiss(result)

    @on(Button.Pressed, "#cancel-btn")
    def action_cancel(self) -> None:
        self.dismiss(None)


class RepoPickerScreen(ModalScreen[str | None]):
    """Modal screen for picking a GitHub repository with filtering."""

    BINDINGS = [
        Binding("escape", "cancel", "Cancel"),
    ]

    CSS = """
    RepoPickerScreen {
        align: center middle;
    }

    RepoPickerScreen > Container {
        width: 80%;
        height: 80%;
        border: thick $accent;
        background: $surface;
        padding: 1 2;
    }

    RepoPickerScreen #search-input {
        margin-bottom: 1;
    }

    RepoPickerScreen OptionList {
        height: 1fr;
        border: solid $primary;
        margin-bottom: 1;
    }

    RepoPickerScreen #button-row {
        height: auto;
        align: center middle;
    }

    RepoPickerScreen Button {
        margin: 0 1;
    }
    """

    def __init__(self, repos: list[tuple[str, str]]) -> None:
        super().__init__()
        self.repos = repos  # List of (name, url) tuples
        self.filtered_repos = repos.copy()
        self.selected_url: str | None = None

    def compose(self) -> ComposeResult:
        with Container():
            yield Label("Select Repository (type to filter)")
            yield Input(placeholder="Search repos...", id="search-input")
            yield OptionList(*[Option(name, id=url) for name, url in self.repos], id="repo-list")
            with Horizontal(id="button-row"):
                yield Button("Select", variant="primary", id="select-btn")
                yield Button("Clear", variant="warning", id="clear-btn")
                yield Button("Cancel", variant="default", id="cancel-btn")

    def on_mount(self) -> None:
        self.query_one("#search-input", Input).focus()

    @on(Input.Changed, "#search-input")
    def on_search_changed(self, event: Input.Changed) -> None:
        search_term = event.value.lower()
        option_list = self.query_one("#repo-list", OptionList)
        option_list.clear_options()

        self.filtered_repos = [
            (name, url) for name, url in self.repos
            if search_term in name.lower()
        ]

        for name, url in self.filtered_repos:
            option_list.add_option(Option(name, id=url))

    @on(OptionList.OptionSelected)
    def on_option_selected(self, event: OptionList.OptionSelected) -> None:
        self.selected_url = str(event.option.id) if event.option.id else None

    @on(OptionList.OptionHighlighted)
    def on_option_highlighted(self, event: OptionList.OptionHighlighted) -> None:
        self.selected_url = str(event.option.id) if event.option.id else None

    @on(Button.Pressed, "#select-btn")
    def on_select(self) -> None:
        self.dismiss(self.selected_url)

    @on(Button.Pressed, "#clear-btn")
    def on_clear(self) -> None:
        self.dismiss("")

    @on(Button.Pressed, "#cancel-btn")
    def action_cancel(self) -> None:
        self.dismiss(None)


class SimpleDevEnvApp(App):
    """TUI for setting up Odoo development environments."""

    TITLE = "Simple DevEnv - Odoo Setup"
    SUB_TITLE = "Create development environments with ease"

    BINDINGS = [
        Binding("q", "quit", "Quit"),
        Binding("ctrl+c", "quit", "Quit"),
    ]

    CSS = """
    Screen {
        background: $surface;
    }

    #main-container {
        padding: 1 2;
    }

    #form-container {
        height: auto;
        padding: 1;
        border: solid $primary;
        margin-bottom: 1;
    }

    .form-row {
        height: auto;
        margin-bottom: 1;
    }

    .form-row Label {
        width: 20;
        padding: 1 1 0 0;
    }

    .form-row Input {
        width: 1fr;
    }

    .form-row Select {
        width: 1fr;
    }

    .form-row Checkbox {
        padding: 1 0 0 0;
    }

    #dir-row {
        height: auto;
    }

    #dir-row Label {
        width: 20;
        padding: 1 1 0 0;
    }

    #target-dir-display {
        width: 1fr;
        padding: 1;
        background: $primary-background;
    }

    #browse-btn {
        margin-left: 1;
    }

    #repo-display {
        width: 1fr;
        padding: 1;
        background: $primary-background;
    }

    #select-repo-btn {
        margin-left: 1;
    }

    #button-row {
        height: auto;
        margin-top: 1;
        align: center middle;
    }

    #button-row Button {
        margin: 0 1;
    }

    #log-container {
        height: 1fr;
        border: solid $accent;
        margin-top: 1;
    }

    #log-container Label {
        height: auto;
        padding: 0 1;
        background: $accent;
        color: $text;
    }

    Log {
        height: 1fr;
    }

    #status-bar {
        height: auto;
        padding: 1;
        background: $primary-background;
        text-align: center;
    }

    .error {
        color: $error;
    }

    .success {
        color: $success;
    }
    """

    def __init__(self) -> None:
        super().__init__()
        self.script_dir = Path(__file__).parent.resolve()
        self.target_dir = Path.home() / "odoo_projects"
        self.github_repos: list[tuple[str, str]] = []
        self.selected_repo: str = ""

    def compose(self) -> ComposeResult:
        yield Header()
        with VerticalScroll(id="main-container"):
            with Container(id="form-container"):
                with Horizontal(classes="form-row"):
                    yield Label("Project Name:")
                    yield Input(placeholder="e.g., houtland-18", id="project-name")

                with Horizontal(classes="form-row"):
                    yield Label("Odoo Version:")
                    yield Select(
                        [
                            ("master", "master"),
                            ("19.0", "19.0"),
                            ("18.0", "18.0"),
                            ("17.0", "17.0"),
                            ("16.0", "16.0"),
                            ("14.0", "14.0"),
                        ],
                        value="18.0",
                        id="odoo-version",
                    )

                with Horizontal(id="dir-row", classes="form-row"):
                    yield Label("Target Directory:")
                    yield Static(str(self.target_dir), id="target-dir-display")
                    yield Button("Browse...", id="browse-btn")

                with Horizontal(classes="form-row"):
                    yield Label("Database Name:")
                    yield Input(placeholder="e.g., myproject (optional)", id="db-name")

                with Horizontal(classes="form-row"):
                    yield Label("")
                    yield Checkbox("Install pre-commit hooks", id="precommit")

                with Horizontal(classes="form-row"):
                    yield Label("Clone Git Repo:")
                    yield Static("(none)", id="repo-display")
                    yield Button("Select...", id="select-repo-btn")

                with Horizontal(id="button-row"):
                    yield Button(
                        "Create Environment", variant="primary", id="create-btn"
                    )

            with Vertical(id="log-container"):
                yield Label("Output Log")
                yield Log(id="log", highlight=True)

            yield Static("Ready", id="status-bar")

        yield Footer()

    def on_mount(self) -> None:
        self.query_one("#project-name", Input).focus()

    @on(Button.Pressed, "#browse-btn")
    def on_browse(self) -> None:
        self.push_screen(
            DirectoryPickerScreen(Path.home()), self.on_directory_picked
        )

    def on_directory_picked(self, path: Path | None) -> None:
        if path is not None:
            self.target_dir = path
            self.query_one("#target-dir-display", Static).update(str(path))

    @on(Button.Pressed, "#select-repo-btn")
    def on_select_repo(self) -> None:
        """Open repo picker, loading repos if needed."""
        if not self.github_repos:
            self.update_status("Loading GitHub repos...")
            try:
                import json
                all_repos = []

                # Load personal repos
                result = subprocess.run(
                    ["gh", "repo", "list", "--limit", "100", "--json", "nameWithOwner,url"],
                    capture_output=True,
                    text=True,
                )
                if result.returncode == 0:
                    repos = json.loads(result.stdout)
                    all_repos.extend([(r["nameWithOwner"], r["url"]) for r in repos])

                # Load AbstractiveOdooPartner org repos
                result = subprocess.run(
                    ["gh", "repo", "list", "AbstractiveOdooPartner", "--limit", "100", "--json", "nameWithOwner,url"],
                    capture_output=True,
                    text=True,
                )
                if result.returncode == 0:
                    repos = json.loads(result.stdout)
                    all_repos.extend([(r["nameWithOwner"], r["url"]) for r in repos])

                if not all_repos:
                    self.update_status("Failed to load repos. Is gh authenticated?", error=True)
                    return

                # Remove duplicates and sort
                self.github_repos = sorted(set(all_repos), key=lambda x: x[0].lower())
                self.update_status(f"Loaded {len(self.github_repos)} repos")

            except FileNotFoundError:
                self.update_status("gh CLI not found. Install it from https://cli.github.com", error=True)
                return
            except Exception as e:
                self.update_status(f"Error loading repos: {e}", error=True)
                return

        self.push_screen(RepoPickerScreen(self.github_repos), self.on_repo_picked)

    def on_repo_picked(self, url: str | None) -> None:
        """Handle repo selection from picker."""
        if url is None:
            return  # Cancelled
        self.selected_repo = url
        if url:
            # Find the name for this URL
            name = next((n for n, u in self.github_repos if u == url), url)
            self.query_one("#repo-display", Static).update(name)
        else:
            self.query_one("#repo-display", Static).update("(none)")

    @on(Button.Pressed, "#create-btn")
    def on_create(self) -> None:
        project_name = self.query_one("#project-name", Input).value.strip()
        odoo_version = self.query_one("#odoo-version", Select).value
        db_name = self.query_one("#db-name", Input).value.strip()
        install_precommit = self.query_one("#precommit", Checkbox).value
        clone_repo = self.selected_repo

        # Validation
        if not project_name:
            self.update_status("Please enter a project name", error=True)
            self.query_one("#project-name", Input).focus()
            return

        if not project_name.replace("-", "").replace("_", "").isalnum():
            self.update_status(
                "Project name should only contain letters, numbers, - and _",
                error=True,
            )
            return

        self.run_setup(project_name, str(odoo_version), db_name, install_precommit, clone_repo)

    def run_setup(
        self, project_name: str, odoo_version: str, db_name: str, install_precommit: bool, clone_repo: str
    ) -> None:
        """Run the setup script, suspending TUI for interactive terminal access."""
        script_path = self.script_dir / "create.sh"

        if not script_path.exists():
            self.update_status("Setup script not found!", error=True)
            return

        # Set environment variables
        env = os.environ.copy()
        env["BASE_PATH"] = str(self.target_dir)
        if db_name:
            env["DB_NAME"] = db_name
        if install_precommit:
            env["INSTALL_PRECOMMIT"] = "1"
        if clone_repo:
            env["CLONE_REPO"] = clone_repo

        # Suspend TUI and run script interactively
        with self.suspend():
            print(f"\n{'='*60}")
            print(f"Setting up {project_name} with Odoo {odoo_version}")
            print(f"Target: {self.target_dir}")
            if clone_repo:
                print(f"Clone repo: {clone_repo}")
            print(f"{'='*60}\n")

            result = subprocess.run(
                ["bash", str(script_path), project_name, odoo_version],
                env=env,
                cwd=str(self.script_dir),
            )

            print(f"\n{'='*60}")
            if result.returncode == 0:
                print("Setup completed successfully!")
            else:
                print(f"Setup failed with exit code {result.returncode}")
            print("Press Enter to return to the TUI...")
            input()

        # Update status after returning
        log = self.query_one("#log", Log)
        log.clear()
        if result.returncode == 0:
            log.write_line(f"Setup completed for {project_name}")
            self.update_status("Environment created successfully!", success=True)
        else:
            log.write_line(f"Setup failed with exit code {result.returncode}")
            self.update_status(f"Setup failed (exit code {result.returncode})", error=True)

    def update_status(
        self, message: str, error: bool = False, success: bool = False
    ) -> None:
        status_bar = self.query_one("#status-bar", Static)
        if error:
            status_bar.update(f"[bold red]{message}[/]")
        elif success:
            status_bar.update(f"[bold green]{message}[/]")
        else:
            status_bar.update(f"[bold]{message}[/]")


def main() -> None:
    app = SimpleDevEnvApp()
    app.run()


if __name__ == "__main__":
    main()
