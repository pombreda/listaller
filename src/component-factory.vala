/* component-factory.vala -- Read and process component information
 *
 * Copyright (C) 2012-2013 Matthias Klumpp <matthias@tenstral.net>
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
using Listaller.Utils;

namespace Listaller.Dep {

/**
 * Read and process component information
 *
 * The ComponentFactory is responsible for compiling a list of available components
 * and to check if their requirements are met.
 * It can also generate new components on the fly.
 */
private class ComponentFactory : Object {
	private string system_components_dir;

	public HashMap<string, Dep.Framework> registered_frameworks { get; private set; }
	public HashMap<string, Dep.Module> registered_modules { get; private set; }

	public ComponentFactory () {
		system_components_dir = PkgConfig.DATADIR + "/listaller/components";

		registered_frameworks = new HashMap<string, Dep.Framework> ();
		registered_modules = new HashMap<string, Dep.Module> ();
	}

	public void initialize () {
		HashSet<string>? framework_info_files = find_files_matching (Path.build_filename (system_components_dir, "frameworks", null), "*.framework");
		HashSet<string>? module_info_files = find_files_matching (Path.build_filename (system_components_dir, "modules", null), "*.module");

		// process all framework data
		if (framework_info_files != null) {
			foreach (string fname in framework_info_files) {
				var cfrmw = new Dep.Framework ();
				bool ret = cfrmw.load_from_file (fname);
				if (ret)
					registered_frameworks.set (cfrmw.idname, cfrmw);
				else
					warning ("Unable to load data for framework: %s", fname);
			}
		}

		// process all module data
		if (module_info_files != null) {
			foreach (string fname in module_info_files) {
				var cmod = new Dep.Module ();
				bool ret = cmod.load_from_file (fname);
				if (ret)
					registered_modules.set (cmod.idname, cmod);
				else
					warning ("Unable to load data for module: %s", fname);
			}
		}
	}

	/**
	 * Check for a valid version-compare string
	 */
	private bool version_comp_is_valid (string version_str) {
		string vs = version_str;
		return vs.has_prefix ("<< ") || vs.has_prefix (">> ") || vs.has_prefix ("<= ") || vs.has_prefix (">= ") || vs.has_prefix ("== ");
	}

	private bool check_framework_installed (Dep.Framework cfrmw) {
		if (cfrmw.installed)
			return true;

		// TODO
		return false;
	}

	private bool check_module_installed (Dep.Module cmod, out string reason = null) {
		if (cmod.installed)
			return true;

		// TODO
		return false;
	}

	public bool component_version_satisfied (string version, string reference_version, string relation) {
		bool ret = false;

		int compare_result = compare_versions (version, reference_version);
		switch (relation) {
				case "==":
				case "<=":
				case ">=":
				ret = compare_result == 0;
				break;
		}
		if (ret)
			return true;

		if (relation.index_of (">") > 0)
			return compare_result > 0;
		if (relation.index_of ("<") > 0)
			return compare_result < 0;

		critical ("Unable to compare versions for relation: %s (this should never happen)", relation);
		return false;
	}

	public bool is_satisfied (string idname, string version_comp, out string reason = null) {
		if (!version_comp_is_valid (version_comp)) {
			warning ("Version compare string %s is not valid!", version_comp);
			return false;
		}

		bool ret = false;
		// prepare our version
		string[] vparts = version_comp.split (" ", 1);
		string required_version = vparts[1].strip ();
		string required_version_relation = vparts[0].strip ();

		if (registered_frameworks.has_key (idname)) {
			Dep.Framework cfrmw = registered_frameworks.get (idname);
			check_framework_installed (cfrmw);
			if (!cfrmw.installed) {
				reason = _("Framework %s is not installed! Please make it available to continue.").printf (cfrmw.full_name);
				return false;
			}

			string c_version;
			try {
				c_version = cfrmw.get_version ();
			} catch (Error e) {
				reason = e.message;
				return false;
			}

			ret = component_version_satisfied (c_version, required_version, required_version_relation);
			if (!ret)
				reason = _("Framework %s is only available in version %s, while a version %s %s is required. This software can not be installed, please notify the original author about it.").printf (cfrmw.full_name,
																										c_version,
																										required_version,
																										required_version_relation);
			return ret;

		} else if (registered_modules.has_key (idname)) {
			// TODO: Resolve module (installed? all dependencies installed?)
			Dep.Module cmod = registered_modules.get (idname);
			string ic_reason;
			check_module_installed (cmod, out ic_reason);
			if (!cmod.installed) {
				reason = ic_reason;
				return false;
			}

			string c_version;
			try {
				c_version = cmod.get_version ();
			} catch (Error e) {
				reason = e.message;
				return false;
			}

			ret = component_version_satisfied (c_version, required_version, required_version_relation);
			if (!ret)
				reason = _("Module %s is only available in version %s, while a version %s %s is required. This software can not be installed, please notify the original author about it.").printf (cmod.full_name,
																										c_version,
																										required_version,
																										required_version_relation);
			return ret;
		} else {
			debug ("No framework/module matching '%s' (v%s) found!", idname, version_comp);

			return false;
		}
	}

	public Dep.Framework? get_framework (string name) {
		return null;
	}

	public Dep.Module? get_module (string name) {
		return null;
	}
}

} // End of namespace: Listaller.Dep
