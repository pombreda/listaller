/* depinfo.vala
 *
 * Copyright (C) 2011 Matthias Klumpp <matthias@nlinux.org>
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
using Gee;
using Listaller;

namespace Listaller.IPK {

public class Dependency : Object {
	private string _full_name;
	public string full_name {
		get {
			if (_full_name == "")
				_full_name = idname;
			if (_full_name == "")
				return "empty";
			return _full_name;
		}
		set {
			_full_name = value;
		}
	}
	public string summary { get; set; }
	public string description { get; set; }
	public string homepage { get; set; }
	public string author { get; set; }
	public string version { get; set; }

	public bool satisfied { get; set; }
	public string architecture { get; set; } // e.g. linux-amd64
	public HashSet<string> meta_info { get; set; }
	public bool is_standardlib { get; set; }

	public string feed_url { get; set; }
	public ArrayList<string> files { get; set; }

	public int64 install_time { get; set; }
	public string environment { get; set; }

	private string _idname;
	public string idname {
		get {
			if (_idname != "")
				return _idname;
			// Form unique dependency-id, if not already set
			_idname = "%s-%s".printf (full_name, version);
			_idname = _idname.down ().replace (" ", "_");
			return _idname;
		}
		set {
			_idname = value;
		}
	}

	internal Dependency.blank () {
		satisfied = false;
		is_standardlib = false;

		files = new ArrayList<string> ();
		meta_info = new HashSet<string> ();
		feed_url = "";
		version = "0";
		idname = "";
		install_time = -1;
		environment = "";
		author = "";
		full_name = "";
	}

	internal Dependency (string depIdName, string depFullName = "", string depVersion = "0") {
		this.blank ();
		idname = depIdName;
		if (depFullName == "")
			full_name = idname;
		else
			full_name = depFullName;
		version = depVersion;
	}

	public void regenerate_depid () {
		if (full_name == "empty") {
			warning ("Dependency full_name is empty! Something is going wrong here...");
			full_name = "empty";
		}
		_idname = "";
		_idname = idname;
	}
}

} // End of namespace: Listaller.IPK

namespace Listaller {

private class DepInfo : Object {
	private ArrayList<IPK.Dependency> dlist;

	enum DepInfoBlock {
		UNKNOWN,
		NAME,
		FILES;
	}

	public DepInfo () {
		Listaller.Settings conf = new Listaller.Settings (true);
		string fname = Path.build_filename (conf.conf_dir (), "dependencies.list", null);

		dlist = new ArrayList<IPK.Dependency> ();
		var file = File.new_for_path (fname);
		if (!file.query_exists ()) {
			return;
		}

		try {
			var dis = new DataInputStream (file.read ());
			string line;
			IPK.Dependency? dep = null;
			DepInfoBlock mode = DepInfoBlock.UNKNOWN;

			// Read lines until end of file (null) is reached
			while ((line = dis.read_line (null)) != null) {
				if (line.has_prefix ("#"))
					continue;

				if (line.strip () == "") {
					if ((dep != null) && (dep.full_name != ""))
						dlist.add (dep);
					dep = new IPK.Dependency ("");
					mode = DepInfoBlock.UNKNOWN;
					continue;
				}
				if (line.down ().has_prefix ("name:")) {
					dep.full_name = line.substring (line.index_of (":") + 1).strip ();
					continue;
				}
				if (line.down ().has_prefix ("id:")) {
					dep.idname = line.substring (line.index_of (":") + 1).strip ();
					continue;
				}
				if (line.down ().has_prefix ("feed:")) {
					dep.feed_url = line.substring (line.index_of (":") + 1).strip ();
					continue;
				}
				if (line.down ().has_prefix ("standard:")) {
					string s = line.substring (line.index_of (":") + 1).strip ();
					if (s.down () == "true")
						dep.is_standardlib = true;
					continue;
				}
				if (line.down ().has_prefix ("files:")) {
					string s = line.substring (line.index_of (":") + 1).strip ();
					if (s != "")
						dep.files.add (s);
					mode = DepInfoBlock.FILES;
					continue;
				}
				if (line.substring (0, 1) == " ") {
					if (mode == DepInfoBlock.FILES)
						dep.files.add (line.strip ());

				}
			}
			if (dep != null)
				dlist.add (dep);
		} catch (Error e) {
			li_error (_("Unable to fetch dependency information list: %s").printf (e.message));
			return;
		}
	}

	public IPK.Dependency? get_dep_template_for_file (string fname) {
		foreach (IPK.Dependency dep in dlist) {
			foreach (string s in dep.files) {
				if (fname == s)
					return dep;
				if (PatternSpec.match_simple (s, fname))
					return dep;
			}
		}
		return null;
	}

	public void update_dependency_with_system_data (ref IPK.Dependency dep, bool pedantic = false) {
		foreach (IPK.Dependency sydep in dlist) {
			if (pedantic) {
				if (sydep.idname == dep.idname) {
					dep = sydep;
					break;
				}
			} else {
				if (sydep.full_name == dep.full_name) {
					dep = sydep;
					break;
				}
			}
		}
	}

}

} // End of namespace: Listaller
