/* reporting.vala
 *
 * Copyright (C) 2012 Matthias Klumpp <matthias@tenstral.net>
 *
 * Licensed under the GNU Lesser General Public License Version 3
 *
 * This library is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library.  If not, see <http://www.gnu.org/licenses/>.
 */

using GLib;

namespace Listaller {

public enum ReportMessageType {
	INFO,
	SUGGESTION,
	WARNING,
	CRITICAL,
	ERROR;

	internal string to_string() {
		switch (this) {
			case INFO:
				return ("I");

			case SUGGESTION:
				return ("S");

			case WARNING:
				return ("W");

			case CRITICAL:
				return ("C");

			case ERROR:
				return ("E");

			default:
				return ("X");
		}
	}
}

public class Report : Object {
	private static Report instance;

	private Array<string> lines; // probably use a HashSet later...
	private bool error_received;

	public Report () {
		lines = new Array<string> ();
		error_received = false;
	}

	public bool contains_error () {
		return error_received;
	}

	public void add_message (ReportMessageType mtype, string message) {
		string prefix = " %s: ".printf (mtype.to_string ());
		lines.append_val ("%s%s".printf (prefix, message));
		if (mtype == ReportMessageType.ERROR)
			error_received = true;
	}

	public void add_info (string message) {
		add_message (ReportMessageType.INFO, message);
	}

	public void add_warning (string message) {
		add_message (ReportMessageType.WARNING, message);
	}

	public string to_string () {
		string str = "";
		for (uint i=0; i < lines.length; i++) {
			str += "%s\n".printf (lines.index (i));
		}

		return str;
	}

	public void clear () {
		lines.set_size (0);
	}

	public static Report get_instance () {
		if (Report.instance == null)
			Report.instance = new Report ();
		return Report.instance;
	}

	public static void delete () {
		Report.instance = null;
	}

	public static void new_message (ReportMessageType mtype, string message) {
		get_instance ().add_message (mtype, message);
	}

	public static void new_info (string message) {
		get_instance ().add_info (message);
	}

	public static void new_warning (string message) {
		get_instance ().add_warning (message);
	}

	public static void clear_current () {
		get_instance ().clear ();
	}
}

} // End of namespace: Listaller
