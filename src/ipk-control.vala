/* ipk-control.vala - Describes data controlling the IPK setup process
 *
 * Copyright (C) 2010-2011 Matthias Klumpp <matthias@tenstral.net>
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
using Xml;
using Gee;
using Listaller;
using Listaller.Utils;

// We need this to produce formatted output
private static extern int xmlThrDefIndentTreeOutput (int val);
private static extern int xmlThrDefKeepBlanksDefaultValue (int val);

namespace Listaller.IPK {

public abstract class CXml : Object {
	private string fname;
	private Xml.Doc* _xdoc;

	internal Xml.Doc* xdoc {
		get { return _xdoc; }
		set { _xdoc = value; }
	}

	internal CXml () {
		fname = "";
		xdoc = null;
	}

	~CXml () {
		if (xdoc != null)
			delete xdoc;
	}

	protected bool open (string path) {
		// Already opened?
		if (xdoc != null) {
			warning ("You have to close the IPK XML first to reopen a new one!");
			return false;
		}
		fname = path;

		// Parse the document from path
		xdoc = Parser.parse_file (fname);
		if (xdoc == null) {
			warning (_("File %s not found or permission denied!"), path);
			return false;
		}

		// Get the root node
		Xml.Node* root = xdoc->get_root_element ();
		if ((root == null) || (root->name != "ipkcontrol")) {
			warning (_("XML file '%s' is damaged."), path);
			return false;
		}

		// If we got here, everything is fine
		return true;
	}

	public bool create_new () {
		// Already opened?
		if (xdoc != null) {
			warning ("You have to close the IPK XML first to create a new one!");
			return false;
		}

		// Helber node
		Xml.Node* nd;

		xdoc = new Doc ("1.0");
		Xml.Node* root = new Xml.Node (null, "ipkcontrol");
		xdoc->set_root_element (root);

		root->new_prop ("version", "1.1~pre");

		root->new_text_child (null, "application", "");

		Xml.Node* comment = new Xml.Node.comment ("IPK control description spec not yet completed!");
		root->add_child (comment);
		return true;
	}

	public void test_dump_xml () {
		string xmlstr;
		// This throws a compiler warning, see bug #547364
		xdoc->dump_memory_format (out xmlstr);
		xmlstr = "\n" + xmlstr + "\n";
		debug (xmlstr);
	}

	private Xml.Node* root_node () {
		Xml.Node* root = xdoc->get_root_element ();
		if ((root == null) || (root->name != "ipkcontrol")) {
			error (_("XML file is damaged or XML structure is no valid IPKControl!"));
			return null;
		}
		return root;
	}

	internal Xml.Node* app_node () {
		Xml.Node* appnd = get_xsubnode (root_node (), "application");
		if (appnd == null)
			error (_("XML file is damaged or XML structure is no valid IPKControl!"));
		return appnd;
	}

	internal Xml.Node* pkg_node () {
		Xml.Node* pkgnd = get_xsubnode (root_node (), "package");
		if (pkgnd == null)
			error (_("XML file is damaged or XML structure is no valid IPKControl!"));
		return pkgnd;
	}

	internal Xml.Node* get_xsubnode (Xml.Node* sn, string id, string attr = "", string attr_value = "") {
		Xml.Node* res = null;
		assert (sn != null);

		for (Xml.Node* iter = sn->children; iter != null; iter = iter->next) {
			// Spaces between tags are also nodes, discard them
			if (iter->type != ElementType.ELEMENT_NODE) {
				continue;
			}
			if (iter->name == id) {
				if (attr != "") {
					if (get_node_content (get_xproperty (iter, attr)) == attr_value) {
						res = iter;
						break;
					}
				} else {
					res = iter;
					break;
				}
			}
		}
		// If node was not found, create new one
		if (res == null) {
			res = sn->new_text_child (null, id, "");
			if (attr != "")
				res->new_prop (attr, attr_value);
		}
		return res;
	}

	internal Xml.Node* get_xproperty (Xml.Node* nd, string id) {
		Xml.Node* res = null;
		assert (nd != null);
		for (Xml.Attr* prop = nd->properties; prop != null; prop = prop->next) {
			string attr_name = prop->name;
			if (attr_name == id) {
				res = prop->children;
				break;
			}
		}
		// If no property was found, create new one
		if (res == null)
			res = nd->new_prop (id, "")->children;
		return res;
	}

	internal string get_node_content (Xml.Node* nd) {
		string ret = "";
		ret = nd->get_content ();
		// TODO: Translate the string
		return ret;
	}

	// Setter/Getter methods for XML properties
	// Package itself

	public void set_pkg_dependencies (ArrayList<Dependency> list) {
		// Create dependencies node
		Xml.Node* n = get_xsubnode (pkg_node (), "requires");
		assert (n != null);

		// Add the dependencies
		foreach (Dependency dep in list) {
			Xml.Node *depnode = n->new_child (null, dep.idname);

			// If we have a feed-url for this, add it
			if (dep.feed_url != "") {
				Xml.Node *fn = get_xproperty (depnode, "feed");
				fn->set_content (dep.feed_url);
			}

			// Add the file-list
			foreach (string s in dep.raw_complist) {
				Deps.ComponentType dct = dep.component_get_type (s);
				string cname = dep.component_get_name (s);
				if (dct == Deps.ComponentType.SHARED_LIB)
					depnode->new_text_child (null, "lib", cname);
				else if (dct == Deps.ComponentType.PYTHON)
					depnode->new_text_child (null, "python", cname);
				else
					depnode->new_text_child (null, "file", cname);
			}
		}
	}

	public ArrayList<Dependency> get_pkg_dependencies () {
		Xml.Node* n = get_xsubnode (pkg_node (), "requires");
		ArrayList<Dependency> depList = new ArrayList<Dependency> ();
		for (Xml.Node* iter = n->children; iter != null; iter = iter->next) {
			// Spaces between tags are also nodes, discard them
			if (iter->type != ElementType.ELEMENT_NODE) {
				continue;
			}
			Dependency dep = new Dependency (iter->name);

			string s = get_xproperty (iter, "feed")->get_content ();
			if (s.strip () != "")
				dep.feed_url = s;

			// Fill dependency entry
			for (Xml.Node* in = iter->children; in != null; in = in->next) {
				// Spaces between tags are also nodes, discard them
				if (in->type != ElementType.ELEMENT_NODE) {
					continue;
				}

				if (in->name == "lib") {
					dep.add_component (in->get_content (), Deps.ComponentType.SHARED_LIB);
				}
				if (in->name == "python") {
					dep.add_component (in->get_content (), Deps.ComponentType.PYTHON);
				}
				if (in->name == "file") {
					li_warning ("Resource %s depends on a file (%s), which is not supported at time.".printf (dep.idname, in->get_content ()));
					dep.add_component (in->get_content (), Deps.ComponentType.FILE);
				}
			}
			depList.add (dep);
		}
		return depList;
	}

	// Application
	protected void set_app_str (string name, string content) {
		if (content == "")
			return;
		Xml.Node* n = get_xsubnode (app_node (), name);
		n->set_content (content);
	}

	protected string get_app_str (string name) {
		if (name == "")
			return "";
		return get_node_content (get_xsubnode (app_node (), name));
	}

	protected void set_app_id (string type, string s) {
		Xml.Node* n = get_xsubnode (app_node (), "id", "type", type);
		n->set_content (s);
	}

	protected string get_app_id (string type) {
		return get_node_content (get_xsubnode (app_node (), "id", "type", type));
	}

	public void set_application (AppItem app) {
		if (app.desktop_file != "") {
			Xml.Node* n1;
			n1 = app_node()->new_text_child (null, "id", app.desktop_file);
			n1->new_prop ("type", "desktop");
		}
		set_app_id ("idname", app.idname);
		set_app_id ("desktop", app.desktop_file);

		Xml.Node* n2 = get_xproperty (app_node (), "name");
		n2->set_content (app.full_name);
		Xml.Node* n3 = get_xproperty (app_node (), "version");
		n3->set_content (app.version);
		set_app_str ("summary", app.summary);
		set_app_str ("url", app.website);
	}

	public AppItem get_application () {
		Xml.Node* ndN = get_xproperty (app_node (), "name");
		Xml.Node* ndV = get_xproperty (app_node (), "version");
		AppItem app = new AppItem (ndN->get_content (), ndV->get_content ());

		app.summary = get_app_str ("summary");
		app.website = get_app_str ("url");
		app.idname = get_app_id ("idname");
		app.desktop_file = get_app_id ("desktop");

		return app;
	}

	public virtual void set_app_description (string text) {
		Xml.Node* n = get_xsubnode (app_node (), "description");
		n->set_content (text);
	}

	public virtual string get_app_description () {
		return get_node_content (get_xsubnode (app_node (), "description"));
	}

	public virtual void set_app_license (string text) {
		Xml.Node* n = get_xsubnode (app_node (), "license");
		n->set_content (text);
	}

	public virtual string get_app_license () {
		return get_node_content (get_xsubnode (app_node (), "license"));
	}


}

public class ControlData : Object {
	private DoapData doap;
	private MetaFile depData;
	protected string ctrlDir;

	public ControlData () {
		doap = new DoapData ();
		depData = new MetaFile ();
		ctrlDir = "";
	}

	private string find_doap_data (string dir) {
		string doapFile = "";
		try {
			var directory = File.new_for_path (dir);
			var enumerator = directory.enumerate_children (FILE_ATTRIBUTE_STANDARD_NAME, 0);

			FileInfo file_info;
			while ((file_info = enumerator.next_file ()) != null) {
				string path = Path.build_filename (dir, file_info.get_name (), null);
				if (file_info.get_is_hidden ())
					continue;

				if (path.down ().has_suffix (".doap"))
					doapFile = path;
			}

		} catch (GLib.Error e) {
			stderr.printf (_("Error: %s\n"), e.message);
			return "";
		}
		return doapFile;
	}

	public bool open (string dir) {
		if (doap.get_doap_url () != "")
			return false;

		string doapFile = find_doap_data (dir);
		if (doapFile == "") {
			debug ("No valid DOAP data found in directory %s - Can't open control files.", dir);
			return false;
		}

		doap.add_file (doapFile);
		ctrlDir = dir;

		// TODO: Load all other data too

		return true;
	}

	public AppItem get_application () {
		AppItem item = doap.get_project ();
		return item;
	}

	public void set_pkg_dependencies (ArrayList<Dependency> list) {
		// Add the dependencies
		foreach (Dependency dep in list) {
			depData.reset ();

			depData.add_value ("Name", dep.full_name);
			depData.add_value ("ID", dep.idname);
			// If we have a feed-url for this, add it
			if (dep.feed_url != "")
				depData.add_value ("Feed", dep.feed_url);

			// TODO
			#if 0
			// Add the file-list
			foreach (string s in dep.raw_complist) {
				Deps.ComponentType dct = dep.component_get_type (s);
				string cname = dep.component_get_name (s);
				if (dct == Deps.ComponentType.SHARED_LIB)
					depnode->new_text_child (null, "lib", cname);
				else if (dct == Deps.ComponentType.PYTHON)
					depnode->new_text_child (null, "python", cname);
				else
					depnode->new_text_child (null, "file", cname);
			}
			#endif
		}
	}
}

public class Control : CXml {

	public Control () {

	}

	public bool open_file (string fname) {
		return this.open (fname);
	}

	public bool save_to_file (string fname) {
//#if FORMATTED_XML
		xmlThrDefKeepBlanksDefaultValue (1);
		xmlThrDefIndentTreeOutput (1);
//#endif
		return xdoc->save_format_file (fname, 1) == 0;
	}

	public override void set_app_license (string text) {
		base.set_app_license (text);
	}

	private string load_license (string fname) {
		return "::TODO";
	}

	public override string get_app_license () {
		string license = base.get_app_license ();
		switch (license) {
			case "GPLv3+": license = load_license ("gpl-3+");
					break;
			case "GPLv3": license = load_license ("gpl-3");
					break;
			case "GPLv2+": license = load_license ("gpl-2+");
					break;
			case "GPLv2": license = load_license ("gpl-2");
					break;
			case "LGPLv2": license = load_license ("lgpl-2");
					break;
			// To be continued...
			default: break;

		}
		return license;
	}

	public override void set_app_description (string text) {
		Xml.Node *cdata = xdoc->new_cdata_block (text, text.length);
		Xml.Node *n = get_xsubnode (app_node (), "description");
		n->add_child (cdata);
	}

	public override string get_app_description () {
		return get_node_content (get_xsubnode (app_node (), "description"));
	}

}

public class Script : CXml {

	public Script () {

	}

	public bool load_from_file (string fname) {
		return this.open (fname);
	}

	public bool save_to_file (string fname) {
//#if FORMATTED_XML
		xmlThrDefKeepBlanksDefaultValue (1);
		xmlThrDefIndentTreeOutput (1);
//#endif
		xdoc->save_format_file (fname, 1);
		return true;
	}

	public override void set_app_description (string text) {
		base.set_app_description (text);
	}

	public override string get_app_description () {
		return base.get_app_description ();
	}

	public bool get_autosolve_dependencies () {
		Xml.Node* n = get_xsubnode (pkg_node (), "requires");
		if (get_node_content (get_xproperty (n, "find")) == "auto")
			return true;
		return false;
	}

}

} // End of namespace
