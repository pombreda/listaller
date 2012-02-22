/* signature.vala
 *
 * Copyright (C) 2011-2012 Matthias Klumpp <matthias@tenstral.net>
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
using GPG;
using Listaller;
using Listaller.Utils;

namespace Listaller {

private class GPGSignature : Object {
	private string signtext;

	public SignStatus sigstatus { get; set; }
	public SignValidity validity { get; set; }
	public bool sig_valid { get; set; }

	public GPGSignature (string sig) {
		signtext = sig;
		sig_valid = false;
		sigstatus = SignStatus.UNKNOWN;
		validity = SignValidity.UNKNOWN;
		init_gpgme (Protocol.OpenPGP);
	}

	private void init_gpgme (Protocol proto) {
		GPG.check_version (null);
		Intl.setlocale (LocaleCategory.ALL, "");
		/* Context.set_locale (null, LocaleCategory.CTYPE, Intl.setlocale (LocaleCategory.CTYPE, null)); */
	}

	private bool check_gpg_err (GPGError.ErrorCode err) {
		if (err != GPGError.ErrorCode.NO_ERROR) {
			debug ("GPGError: %s", GPGError.strsource (err));
			return false;
		}
		return true;
	}

	private void set_sigvalidity_from_gpgvalidity (Validity val) {
		switch (val) {
			case Validity.UNKNOWN:
				validity = SignValidity.UNKNOWN;
				break;

			case Validity.UNDEFINED:
				validity = SignValidity.UNDEFINED;
				break;

			case Validity.NEVER:
				validity = SignValidity.NEVER;
				break;

			case Validity.MARGINAL:
				validity = SignValidity.MARGINAL;
				break;

			case Validity.FULL:
				validity = SignValidity.FULL;
				break;

			case Validity.ULTIMATE:
				validity = SignValidity.ULTIMATE;
				break;

			default:
				validity = SignValidity.UNKNOWN;
				break;
		}
	}

	private bool process_sig_result (VerifyResult *result) {
		Signature *sig = result->signatures;

		if ((sig == null) || (sig->next != null)) {
			warning ("Unexpected number of signatures!");
			return false;
		}
		sigstatus = (SignStatus) sig->summary;
		set_sigvalidity_from_gpgvalidity (sig->validity);

		if (sig->status != GPGError.ErrorCode.NO_ERROR) {
			warning ("Unexpected signature status: %s", sig->status.to_string ());
			sig_valid = false;
			return false;
		} else {
			sig_valid = true;
		}
		if (sig->wrong_key_usage) {
			warning ("Unexpectedly wrong key usage");
			return false;
		}

		if (sig->validity_reason != GPGError.ErrorCode.NO_ERROR) {
			li_error ("Unexpected validity reason: %s".printf (sig->validity_reason.to_string ()));
			return false;
		}
		return true;
	}

	private bool read_file_to_data (string fname, Data dt) {
		const uint BUFFER_SIZE = 512;
		dt.set_encoding (DataEncoding.BINARY);

		var file = File.new_for_path (fname);
		var fs = file.read ();
		var data_stream = new DataInputStream (fs);
		data_stream.set_byte_order (DataStreamByteOrder.LITTLE_ENDIAN);

		// Seek and read the image data chunk
		uint8[] buffer = new uint8[BUFFER_SIZE];
		fs.seek (0, SeekType.CUR);
		while (data_stream.read (buffer) > 0)
			dt.write (buffer, BUFFER_SIZE);

		return true;
	}

	private bool verify_package_internal (string ctrlfname, string payloadfname) {
		Context ctx;
		GPGError.ErrorCode err;
		Data sig, dt;
		VerifyResult *result;

		err = Context.Context (out ctx);
		return_if_fail (check_gpg_err (err));

		/* Checking a valid message.  */
		err = Data.create (out dt);
		dt.set_encoding (DataEncoding.BINARY);

		read_file_to_data (ctrlfname, dt);
		read_file_to_data (payloadfname, dt);

		return_if_fail (check_gpg_err (err));

		err = Data.create_from_memory (out sig, signtext, Posix.strlen (signtext), false);
		return_if_fail (check_gpg_err (err));

		err = ctx.op_verify (sig, dt, null);
		return_if_fail (check_gpg_err (err));
		result = ctx.op_verify_result ();

		process_sig_result (result);
		debug ("Signature checked.");
		return true;
	}

	public bool verify_package (string ctrlfname, string payloadfname) {
		bool ret;
		ret = verify_package_internal (ctrlfname, payloadfname);
		if (!ret) {
			debug ("Signature is broken!");
			validity = SignValidity.NEVER;
			sigstatus = SignStatus.RED;
		}
		return ret;
	}
}

} // End of namespace
