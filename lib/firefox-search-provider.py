#!/usr/bin/env python3
"""GNOME Shell search provider forwarding the typed terms to Firefox.

Implements org.gnome.Shell.SearchProvider2 on the session bus with a single
result; activating it runs `firefox --search <terms>`, so the query goes to
whatever search engine the Firefox profile has set as its default.

GNOME Shell only ever passes result identifiers back to GetResultMetas, so the
terms are encoded into the identifier itself. The service is D-Bus activated
and quits after IDLE_TIMEOUT seconds without a call, GNOME Shell respawning it
on the next keystroke.

Environment:
    MX_FIREFOX_BIN                  firefox binary (default: firefox from PATH)
    MX_FIREFOX_SEARCH_LANG          label language: en, fr, es, de
    MX_FIREFOX_SEARCH_BUS_NAME      bus name to own
    MX_FIREFOX_SEARCH_OBJECT_PATH   object path to export
"""

import os
import shutil
import subprocess
import sys
from typing import Any

import dbus
import dbus.service
import gi
from dbus.mainloop.glib import DBusGMainLoop

gi.require_version("GLib", "2.0")
from gi.repository import GLib  # noqa: E402

DEFAULT_BUS_NAME = "org.modulixos.FirefoxSearchProvider"
DEFAULT_OBJECT_PATH = "/org/modulixos/FirefoxSearchProvider"
INTERFACE_NAME = "org.gnome.Shell.SearchProvider2"
RESULT_PREFIX = "mx-firefox-search:"
IDLE_TIMEOUT = 30

TRANSLATIONS: dict[str, dict[str, str]] = {
    "en": {
        "name": "Search for “{terms}”",
        "description": "Search the web with Firefox",
    },
    "fr": {
        "name": "Rechercher « {terms} »",
        "description": "Rechercher sur le Web avec Firefox",
    },
    "es": {
        "name": "Buscar «{terms}»",
        "description": "Buscar en la Web con Firefox",
    },
    "de": {
        "name": "Nach „{terms}“ suchen",
        "description": "Mit Firefox im Web suchen",
    },
}


def language() -> str:
    """Two-letter label language, falling back to "en" when unsupported.

    Reads MX_FIREFOX_SEARCH_LANG first, then the usual locale variables.
    """
    raw = (
        os.environ.get("MX_FIREFOX_SEARCH_LANG")
        or os.environ.get("LC_ALL")
        or os.environ.get("LC_MESSAGES")
        or os.environ.get("LANG")
        or "en"
    )
    code = raw.split(".")[0].split("@")[0].replace("_", "-").split("-")[0].lower()
    return code if code in TRANSLATIONS else "en"


def firefox_binary() -> str | None:
    """Firefox binary set by the wrapper, else the first one found in PATH."""
    candidate = os.environ.get("MX_FIREFOX_BIN")
    if candidate and os.access(candidate, os.X_OK):
        return candidate
    return shutil.which(candidate or "firefox")


class SearchProvider(dbus.service.Object):
    """Session-bus object implementing org.gnome.Shell.SearchProvider2.

    Attributes:
        loop: main loop quit once the provider has been idle long enough.
        strings: label templates for the configured language.
        idle_source: id of the pending idle timeout, 0 when none is armed.
    """

    def __init__(
        self, bus_name: dbus.service.BusName, object_path: str, loop: GLib.MainLoop
    ) -> None:
        """Export the object on `bus_name` at `object_path` and arm the watchdog.

        `loop` is the main loop stopped once the service has gone idle.
        """
        super().__init__(bus_name, object_path)
        self.loop = loop
        self.strings = TRANSLATIONS[language()]
        self.idle_source = 0
        self._rearm_idle()

    def _rearm_idle(self) -> None:
        """Restart the idle countdown, dropping any previously armed timeout."""
        if self.idle_source:
            GLib.source_remove(self.idle_source)
        self.idle_source = GLib.timeout_add_seconds(IDLE_TIMEOUT, self._on_idle)

    def _on_idle(self) -> bool:
        """Quit the main loop; the timeout never re-arms itself."""
        self.idle_source = 0
        self.loop.quit()
        return False

    @dbus.service.method(INTERFACE_NAME, in_signature="as", out_signature="as")
    def GetInitialResultSet(self, terms: list[str]) -> list[str]:  # noqa: N802
        """One identifier carrying the query, or nothing when it is blank."""
        self._rearm_idle()
        return self._results(terms)

    @dbus.service.method(INTERFACE_NAME, in_signature="asas", out_signature="as")
    def GetSubsearchResultSet(  # noqa: N802
        self, _previous_results: list[str], terms: list[str]
    ) -> list[str]:
        """Same single identifier, recomputed for the narrowed-down `terms`."""
        self._rearm_idle()
        return self._results(terms)

    @dbus.service.method(INTERFACE_NAME, in_signature="as", out_signature="aa{sv}")
    def GetResultMetas(self, identifiers: list[str]) -> list[dict[str, Any]]:  # noqa: N802
        """Metadata of the requested identifiers, titled with their query."""
        self._rearm_idle()
        metas = []
        for identifier in identifiers:
            query = identifier.removeprefix(RESULT_PREFIX)
            metas.append(
                dbus.Dictionary(
                    {
                        "id": identifier,
                        "name": self.strings["name"].format(terms=query),
                        "description": self.strings["description"],
                        "gicon": "firefox",
                        "clipboardText": query,
                    },
                    signature="sv",
                )
            )
        return metas

    @dbus.service.method(INTERFACE_NAME, in_signature="sasu", out_signature="")
    def ActivateResult(  # noqa: N802
        self, identifier: str, terms: list[str], _timestamp: int
    ) -> None:
        """Search for `terms`, falling back to the query held by `identifier`."""
        self._rearm_idle()
        self._launch(list(terms) or [identifier.removeprefix(RESULT_PREFIX)])

    @dbus.service.method(INTERFACE_NAME, in_signature="asu", out_signature="")
    def LaunchSearch(self, terms: list[str], _timestamp: int) -> None:  # noqa: N802
        """Search for `terms`, as asked from the provider section header."""
        self._rearm_idle()
        self._launch(list(terms))

    def _results(self, terms: list[str]) -> list[str]:
        """The single result identifier for `terms`, empty when they are blank."""
        query = " ".join(str(term) for term in terms).strip()
        return [RESULT_PREFIX + query] if query else []

    def _launch(self, terms: list[str]) -> None:
        """Run a Firefox search for `terms` with the profile's default engine.

        Blank terms and a missing binary are ignored; a failed spawn is
        reported on stderr rather than killing the service.
        """
        query = " ".join(str(term) for term in terms).strip()
        binary = firefox_binary()
        if not query or binary is None:
            return
        try:
            subprocess.Popen(  # noqa: S603
                [binary, "--search", query],
                start_new_session=True,
            )
        except OSError as error:
            print(f"firefox-search-provider: {error}", file=sys.stderr)


def main() -> int:
    """Export the provider on the session bus and run until idle.

    Returns 1 when the bus name is already owned or the session bus is
    unreachable, 0 otherwise.
    """
    name = os.environ.get("MX_FIREFOX_SEARCH_BUS_NAME", DEFAULT_BUS_NAME)
    path = os.environ.get("MX_FIREFOX_SEARCH_OBJECT_PATH", DEFAULT_OBJECT_PATH)

    DBusGMainLoop(set_as_default=True)
    loop = GLib.MainLoop()
    try:
        bus_name = dbus.service.BusName(name, bus=dbus.SessionBus(), do_not_queue=True)
    except dbus.DBusException as error:
        print(f"firefox-search-provider: {error}", file=sys.stderr)
        return 1

    SearchProvider(bus_name, path, loop)
    loop.run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
