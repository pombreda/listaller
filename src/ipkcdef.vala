/* ipkcdef.vala
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
using Xml;
using Gee;
using Listaller;

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

		root->new_prop ("version", "1.1");

		Xml.Node* subnode = root->new_text_child (null, "application", "");
		nd = subnode->new_text_child (null, "id", "test.desktop" );
		nd->new_prop ("type", "desktop");

		Xml.Node* comment = new Xml.Node.comment ("IPK control description spec not yet completed!");
		root->add_child (comment);
		return true;
	}

	public void print_xml () {
		string xmlstr;
		// This throws a compiler warning, see bug 547364
		xdoc->dump_memory (out xmlstr);

		debug (xmlstr);
	}

	private Xml.Node* root_node () {
		Xml.Node* root = xdoc->get_root_element ();
		if ((root == null) || (root->name != "ipkcontrol")) {
			critical (_("XML file is damaged or XML structure is no valid IPKControl!"));
			return null;
		}
		return root;
	}

	internal Xml.Node* app_node () {
		Xml.Node* appnd = get_xsubnode (root_node (), "application");
		if (appnd == null)
			critical (_("XML file is damaged or XML structure is no valid IPKControl!"));
		return appnd;
	}

	internal Xml.Node* pkg_node () {
		Xml.Node* pkgnd = get_xsubnode (root_node (), "package");
		if (pkgnd == null)
			critical (_("XML file is damaged or XML structure is no valid IPKControl!"));
		return pkgnd;
	}

	internal Xml.Node* get_xsubnode (Xml.Node* sn, string id) {
		Xml.Node* res = null;
		assert (sn != null);

		for (Xml.Node* iter = sn->children; iter != null; iter = iter->next) {
			// Spaces between tags are also nodes, discard them
			if (iter->type != ElementType.ELEMENT_NODE) {
				continue;
			}
			if (iter->name == id) {
				res = iter;
				break;
			}
		}
		// If node was not found, create new one
		if (res == null)
			res = sn->new_text_child (null, id, "");
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
	public void set_pkg_id (string s) {
		Xml.Node* n = get_xsubnode (pkg_node (), "id");
		n->set_content (s);
	}

	public string get_pkg_id () {
		return get_node_content (get_xsubnode (pkg_node (), "id"));
	}

	public void set_pkg_dependencies (ArrayList<string> list) {
		// Create dependencies node
		Xml.Node* n = get_xsubnode (pkg_node (), "dependencies");
		assert (n != null);

		// Add the dependencies
		foreach (string s in list) {
			n->new_text_child (null, "file", s);
		}
	}

	public ArrayList<string> get_pkg_dependencies () {
		Xml.Node* n = get_xsubnode (pkg_node (), "dependencies");
		ArrayList<string> depList = new ArrayList<string> ();
		for (Xml.Node* iter = n->children; iter != null; iter = iter->next) {
			// Spaces between tags are also nodes, discard them
			if (iter->type != ElementType.ELEMENT_NODE) {
				continue;
			}
			if (iter->name == "file") {
				depList.add (iter->get_content ());
			}
		}
		return depList;
	}

	// Application
	public void set_app_name (string s) {
		Xml.Node* n = get_xproperty (app_node (), "name");
		n->set_content (s);
	}

	public string get_app_name () {
		Xml.Node* nd = get_xproperty (app_node (), "name");
		return nd->get_content ();
	}

	public void set_app_version (string s) {
		Xml.Node* n = get_xproperty (app_node (), "version");
		n->set_content (s);
	}

	public string get_app_version () {
		Xml.Node* nd = get_xproperty (app_node (), "version");
		return nd->get_content ();
	}

	public void set_app_summary (string s) {
		Xml.Node* n = get_xsubnode (app_node (), "summary");
		n->set_content (s);
	}

	public string get_app_summary () {
		return get_node_content (get_xsubnode (app_node (), "summary"));
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

	public void set_app_url (string s) {
		Xml.Node* n = get_xsubnode (app_node (), "url");
		n->set_content (s);
	}

	public string get_app_url () {
		return get_node_content (get_xsubnode (app_node (), "url"));
	}

}

public class Control : CXml {

	public Control () {

	}

	public bool open_file (string fname) {
		return this.open (fname);
	}

	public bool save_to_file (string fname) {
		return xdoc->save_file (fname) == 0;
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
		return xdoc->save_file (fname) == 0;
	}

	public override void set_app_description (string text) {
		base.set_app_description (text);
	}

	public override string get_app_description () {
		return base.get_app_description ();
	}

}

} // End of namespace
