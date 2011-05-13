/* database.vala
 *
 * Copyright (C) 2010-2011  Matthias Klumpp
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
using Sqlite;
using Listaller;

namespace Listaller {

public errordomain DatabaseError {
	ERROR,
	BACKING,
	MEMORY,
	ABORT,
	LIMITS,
	TYPESPEC
}

public enum DatabaseStatus {
	OPENED,
	LOCKED,
	UNLOCKED,
	SUCCESS,
	FAILURE,
	FATAL,
	CLOSED;

	public string to_string() {
		switch (this) {
			case OPENED:
				return _("Software database opened");

			case LOCKED:
				return _("Database locked");

			case UNLOCKED:
				return _("Database unlocked");

			case SUCCESS:
				return _("Database action successful");

			case FAILURE:
				return _("Database action failed");

			case FATAL:
				return _("Fatal database error");

			case CLOSED:
				return _("Software database closed");

			default:
				return _("Software database message (%d)").printf((int) this);
		}
	}
}

private class SoftwareDB : Object {
	private Database db;
	private Settings conf;
	private string dblockfile;

	public signal void db_status_changed (DatabaseStatus newstatus, string message);

	public signal void error_code (ErrorItem error);
	public signal void message (MessageItem message);

	public SoftwareDB (Settings? settings) {
		conf = settings;
		if (conf == null)
			conf = new Settings (false);

		dblockfile = conf.appregister_dir () + "/lock";
	}

	~SoftwareDB () {
		// Make sure DB is always closed when DB is freed
		close ();
	}

	public bool database_locked () {
		if (FileUtils.test (dblockfile, FileTest.IS_REGULAR)) {
			return true;
		} else {
			return false;
		}
	}

	private void dbstatus_changed (DatabaseStatus dbs, string details) {
		if ((dbs == DatabaseStatus.FAILURE) ||
			(dbs == DatabaseStatus.FATAL)) {
				// Emit error
				ErrorItem item = new ErrorItem(ErrorEnum.DATABASE_FAILURE);
				item.details = details;
				error_code (item);
				critical (details);
			}
		db_status_changed (dbs, details);
	}

	private void emit_message (string msg) {
		// Construct info message
		MessageItem item = new MessageItem(MessageEnum.INFO);
		item.details = msg;
		message (item);
		GLib.message (msg);
	}

	public bool open () {
		string dbname = conf.database_file ();
		int rc;

		// If database is locked, we should not try to read/write on it
		if (database_locked ()) {
			return false;
		}

		if (!FileUtils.test (dbname, FileTest.IS_REGULAR)) {
			emit_message ("Software database does not exist - will be created.");
		}

		rc = Database.open (dbname, out db);

		if (rc != Sqlite.OK) {
			string msg = "Can't open database! (Message: %d, %s)".printf (rc, db.errmsg ());
			stderr.printf (msg);
			dbstatus_changed (DatabaseStatus.FAILURE, msg);
			return false;
		}

		// Drop "lock" file
		File lfile = File.new_for_path (dblockfile);
		try {
			lfile.create (FileCreateFlags.NONE);
		} catch (Error e) {
			critical ("Error: %s", e.message);
			return false;
		}

		// Test for the existence of file
		if (!lfile.query_exists ()) {
			critical ("Unable to create lock file!");
			return false;
		}

		dbstatus_changed (DatabaseStatus.LOCKED, "");
		dbstatus_changed (DatabaseStatus.OPENED, "");

		// Ensure the database is okay and all tables are created
		if (!update_db_structure ()) {
			dbstatus_changed (DatabaseStatus.FAILURE, _("Could not create/update software database!"));
			return false;
		}

		return true;
	}

	public void close () {
		// Just delete the lock
		remove_db_lock ();
	}

	public void remove_db_lock () {
		File lfile = File.new_for_path (dblockfile);
		try {
			if (lfile.query_exists ()) {
				lfile.delete ();
			}
		} catch (Error e) {
			error (_("Unable to remove database lock! (Message: %s)").printf (e.message));
		}
	}

	/*
	 * This method will throw an error on an SQLite return code unless it's OK, DONE, or ROW, which
	 * are considered normal results.
	 */
	protected void throw_error (string method, int res) throws DatabaseError {
		string msg = "(%s) [%d] - %s".printf (method, res, db.errmsg());

		switch (res) {
			case Sqlite.OK:
			case Sqlite.DONE:
			case Sqlite.ROW:
				return;

			case Sqlite.PERM:
			case Sqlite.BUSY:
			case Sqlite.READONLY:
			case Sqlite.IOERR:
			case Sqlite.CORRUPT:
			case Sqlite.CANTOPEN:
			case Sqlite.NOLFS:
			case Sqlite.AUTH:
			case Sqlite.FORMAT:
			case Sqlite.NOTADB:
				throw new DatabaseError.BACKING (msg);

			case Sqlite.NOMEM:
				throw new DatabaseError.MEMORY (msg);

			case Sqlite.ABORT:
			case Sqlite.LOCKED:
			case Sqlite.INTERRUPT:
				throw new DatabaseError.ABORT (msg);

			case Sqlite.FULL:
			case Sqlite.EMPTY:
			case Sqlite.TOOBIG:
			case Sqlite.CONSTRAINT:
			case Sqlite.RANGE:
				throw new DatabaseError.LIMITS (msg);

			case Sqlite.SCHEMA:
			case Sqlite.MISMATCH:
				throw new DatabaseError.TYPESPEC (msg);

			case Sqlite.ERROR:
			case Sqlite.INTERNAL:
			case Sqlite.MISUSE:
			default:
				throw new DatabaseError.ERROR (msg);
		}
	}

	protected void fatal (string op, int res) {
		string msg = "%s: [%d] %s".printf (op, res, db.errmsg());
		dbstatus_changed (DatabaseStatus.FATAL, msg);
	}

	public bool has_table (string table_name) {
		Sqlite.Statement stmt;
		int res = db.prepare_v2 ("PRAGMA table_info(%s)".printf(table_name), -1, out stmt);
		assert (res == Sqlite.OK);

		res = stmt.step();

		return (res != Sqlite.DONE);
	}

	protected bool update_db_structure () {
		Sqlite.Statement stmt;

		// Create table to store information about applications
		int res = db.prepare_v2 ("CREATE TABLE IF NOT EXISTS applications ("
		+ "id INTEGER PRIMARY KEY, "
		+ "name TEXT NOT NULL, "
		+ "version TEXT NOT NULL, "
		+ "desktop_file TEXT UNIQUE,"
		+ "summary TEXT, "
		+ "author TEXT, "
		+ "pkgmaintainer TEXT, "
		+ "categories TEXT, "
		+ "install_time INTEGER, "
		+ "origin TEXT NOT NULL, "
		+ "dependencies TEXT"
		+ ")", -1, out stmt);
		assert (res == Sqlite.OK);

		res = stmt.step ();
		if (res != Sqlite.DONE) {
			fatal ("create applications table", res);
			return false;
		}

		// Table for all the additional stuff fetched during installation (3rd-party libraries etc.)
		res = db.prepare_v2 ("CREATE TABLE IF NOT EXISTS dependencies ("
		+ "id INTEGER PRIMARY KEY, "
		+ "name TEXT UNIQUE NOT NULL, "
		+ "version TEXT UNIQUE NOT NULL, "
		+ "storage_path TEXT UNIQUE NOT NULL, "
		+ "pkgmaintainer TEXT, "
		+ "install_time INTEGER"
		+ ")", -1, out stmt);
		assert (res == Sqlite.OK);

		res = stmt.step ();
		if (res != Sqlite.DONE) {
			fatal ("create dependencies table", res);
			return false;
		}

		return true;
	}

	public bool add_application (AppItem item) {
		Sqlite.Statement stmt;
		int res = db.prepare_v2 (
			"INSERT INTO applications (name, version, desktop_file, summary, author, pkgmaintainer, "
			+ "categories, install_time, origin, dependencies) "
			+ "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
				   -1, out stmt);
			assert (res == Sqlite.OK);

			ulong time_created = now_sec ();

			// Assign values
			res = stmt.bind_text (1, item.full_name);
			assert (res == Sqlite.OK);
			res = stmt.bind_text (2, item.version);
			assert (res == Sqlite.OK);
			res = stmt.bind_text (3, item.desktop_file);
			assert (res == Sqlite.OK);
			res = stmt.bind_text (4, item.summary);
			assert (res == Sqlite.OK);
			res = stmt.bind_text (5, item.author);
			assert (res == Sqlite.OK);
			res = stmt.bind_text (6, item.maintainer);
			assert (res == Sqlite.OK);
			res = stmt.bind_text (7, item.categories);
			assert (res == Sqlite.OK);
			res = stmt.bind_int64 (8, item.install_time);
			assert (res == Sqlite.OK);
			res = stmt.bind_text (9, item.origin.to_string ());
			assert (res == Sqlite.OK);
			res = stmt.bind_text (10, item.dependencies);
			assert (res == Sqlite.OK);

			res = stmt.step();
			if (res != Sqlite.DONE) {
				if (res != Sqlite.CONSTRAINT) {
					fatal ("add application", res);
					return false;
				}
			}

			return true;
	}

	private AppItem? retrieve_app_item (Sqlite.Statement stmt) {
		AppItem item = new AppItem.blank ();

		item.dbid = stmt.column_int (0);
		item.full_name = stmt.column_text (1);
		item.version = stmt.column_text (2);
		item.desktop_file = stmt.column_text (3);
		item.summary = stmt.column_text (4);
		item.author = stmt.column_text (5);
		item.maintainer = stmt.column_text (6);
		item.categories = stmt.column_text (7);
		item.install_time = stmt.column_int (8);
		item.set_origin_from_string (stmt.column_text (9));
		item.dependencies = stmt.column_text (10);

		return item;
	}

	public AppItem? get_application_by_name (string appName) {
		Sqlite.Statement stmt;
		int res = db.prepare_v2 ("SELECT id, name, desktop_file, version, summary, author, pkgmaintainer, "
		+ "categories, install_time, origin, dependencies "
		+ "FROM applications WHERE name=?", -1, out stmt);
		assert (res == Sqlite.OK);

		res = stmt.bind_text (1, appName);

		if (stmt.step() != Sqlite.ROW)
			return null;

		AppItem item = retrieve_app_item (stmt);

		// Fast sanity checks
		item.fast_check ();

		return item;
	}

	public AppItem? get_application_by_dbid (int databaseId) {
		Sqlite.Statement stmt;
		int res = db.prepare_v2 ("SELECT id, name, version, desktop_file, summary, author, pkgmaintainer, "
		+ "categories, install_time, origin, dependencies "
		+ "FROM applications WHERE id=?", -1, out stmt);
		assert (res == Sqlite.OK);

		res = stmt.bind_int (1, databaseId);

		if (stmt.step() != Sqlite.ROW)
			return null;

		AppItem item = retrieve_app_item (stmt);

		// Fast sanity checks
		item.fast_check ();

		return item;
	}

	public AppItem? get_application_by_name_version (string appName, string appVersion) {
		Sqlite.Statement stmt;
		int res = db.prepare_v2 ("SELECT id, name, version, desktop_file, summary, author, pkgmaintainer, "
		+ "categories, install_time, origin, dependencies "
		+ "FROM applications WHERE name=? AND version=?", -1, out stmt);
		assert (res == Sqlite.OK);

		res = stmt.bind_text (1, appName);
		assert (res == Sqlite.OK);
		res = stmt.bind_text (2, appVersion);
		assert (res == Sqlite.OK);

		if (stmt.step() != Sqlite.ROW)
			return null;

		AppItem item = retrieve_app_item (stmt);

		// Fast sanity checks
		item.fast_check ();

		return item;
	}
}

} // End of namespace
