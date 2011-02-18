/* main.vala
 *
 * Copyright (C) 2010  Matthias Klumpp
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Author:
 * 	Matthias Klumpp <matthias@nlinux.org>
 */

using GLib;

public class RunAppMain : Object {
	private string appName;

	public RunAppMain (string aname) {
		appName = aname;
	}

	public void run_application (string commandLine) {
		try {
			Process.spawn_command_line_sync (commandLine);
		} catch (Error e) {
			stderr.printf ("Could not run: %s\n", e.message);
		}
	}

	public void run () {
		run_application (appName);
	}

	static int main (string[] args) {
		if (args[1] == null) {
			stderr.printf ("No application specified!\n");
			return 5;
		}

		var main = new RunAppMain (args[1]);
		main.run ();
		return 0;
	}

}
