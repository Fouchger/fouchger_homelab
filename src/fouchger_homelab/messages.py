"""messages.py
Notes:
- Custom messages used to communicate between worker threads and the UI.
- Textual's post_message is thread-safe; widgets are not. We use messages
  to keep UI updates on the main thread.
"""

from __future__ import annotations

from dataclasses import dataclass

from textual.message import Message

from .domain.jobs import Job, JobResult


@dataclass
class LogLine(Message):
    """A single log line intended for the LogPanel."""

    text: str


@dataclass
class JobFinished(Message):
    """A job has completed execution."""

    job: Job
    result: JobResult
