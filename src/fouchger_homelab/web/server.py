"""
server.py
Notes:
- Simple FastAPI web UI for fouchger_homelab.
- Reuses existing domain layer (DirectRunner, HistoryStore).
- Designed to work cleanly behind reverse proxies.
"""

from __future__ import annotations

import asyncio
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, Request, Form
from fastapi.responses import HTMLResponse, RedirectResponse, PlainTextResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from ..paths import AppPaths
from ..config import AppConfig
from ..logging_setup import configure_logging
from ..domain.direct_runner import DirectRunner
from ..domain.history_store import HistoryStore
from ..domain.jobs import Job


def create_app() -> FastAPI:
    paths = AppPaths.from_home("fouchger_homelab")
    paths.ensure()
    configure_logging(paths.logs_dir)

    config_path = paths.config_dir / "config.yml"
    cfg = AppConfig.load(config_path)

    runner = DirectRunner(runs_dir=paths.runs_dir)
    history = HistoryStore(db_path=paths.state_dir / "history.db")

    app = FastAPI(title="Fouchger Homelab")

    web_dir = Path(__file__).parent
    templates = Jinja2Templates(directory=str(web_dir / "templates"))

    static_dir = web_dir / "static"
    if static_dir.exists():
        app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")

    @app.get("/", response_class=HTMLResponse)
    def home(request: Request) -> HTMLResponse:
        return templates.TemplateResponse(
            "index.html",
            {
                "request": request,
                "runner_desc": runner.describe(),
            },
        )

    @app.get("/tools", response_class=HTMLResponse)
    def tools(request: Request) -> HTMLResponse:
        return templates.TemplateResponse(
            "tools.html",
            {
                "request": request,
                "sections": [
                    ("proxmox", "Proxmox"),
                    ("ansible", "Ansible"),
                    ("terraform", "Terraform"),
                    ("packer", "Packer"),
                    ("dev-auth", "Developer auth (git + gh)"),
                ],
            },
        )

    @app.get("/history", response_class=HTMLResponse)
    def run_history(request: Request) -> HTMLResponse:
        # If your HistoryStore has a different method name, wire it accordingly.
        rows = history.list_recent(limit=50) if hasattr(history, "list_recent") else []
        return templates.TemplateResponse(
            "history.html",
            {"request": request, "rows": rows},
        )

    @app.post("/run/{tool_key}")
    async def run_tool(tool_key: str, request: Request) -> RedirectResponse:
        """
        Notes:
        - Keep this mapping explicit and boring.
        - You can expand jobs to include args from forms later.
        """
        jobs: dict[str, Job] = {
            "proxmox": Job(name="proxmox", argv=["/usr/bin/true"], cwd=paths.root),
            "ansible": Job(name="ansible", argv=["/usr/bin/true"], cwd=paths.root),
            "terraform": Job(name="terraform", argv=["/usr/bin/true"], cwd=paths.root),
            "packer": Job(name="packer", argv=["/usr/bin/true"], cwd=paths.root),
            "dev-auth": Job(name="dev-auth", argv=["bash", "scripts/core/dev-auth.sh", "all"], cwd=paths.root),
        }
        job = jobs.get(tool_key)
        if not job:
            return RedirectResponse(url="/tools", status_code=303)

        history.record_started(job)
        result = await asyncio.to_thread(runner.execute, job)
        history.record_finished(job, result)

        return RedirectResponse(url="/history", status_code=303)

    @app.get("/healthz", response_class=PlainTextResponse)
    def healthz() -> str:
        return "ok"

    return app


app = create_app()
