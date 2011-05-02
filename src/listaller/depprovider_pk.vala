/* depprovider_pk.vala
 *
 * Copyright (C) 2011  Matthias Klumpp
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
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
using Gee;
using Listaller;

namespace Listaller.Deps {

private class PkitProvider : Provider {
	private PackageKit.Client pkit;

	public PkitProvider (IPK.Dependency ipkdep) {
		base (ipkdep);

		pkit = new PackageKit.Client ();
	}

	private void pk_progress_cb (PackageKit.Progress progress, PackageKit.ProgressType type) {
		//
	}

	private string pkit_pkg_from_file (string fname) {
		PackageKit.Bitfield filter = PackageKit.Filter.bitfield_from_string ("installed");
		string[] files = { fname, null };

		// TODO: Fix PackageKit GIR before this can be used
		//! PackageKit.Results res = pkit.search_files (filter, files, null, pk_progress_cb);
		string[] packages = { "?", null };
		//! packages = res.get_package_sack ().get_ids ();

		stdout.printf (packages[0] + "\n");

		return packages[0];
	}

	public override bool execute () {
		// PK solver can only handle files...
		foreach (string s in dep.files) {
			string pkg = pkit_pkg_from_file (s);
		}
		return false;
	}

}

} // End of namespace
