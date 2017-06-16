/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io),
 *               2013 Julien Spautz <spautz.julien@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License version 3
 * as published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Julien Spautz <spautz.julien@gmail.com>, Andrei-Costin Zisu <matzipan@gmail.com>
 */

namespace Scratch.Plugins.FolderManager {

    /**
     * Class for easily dealing with files.
     */
    internal class File : GLib.Object {

        public GLib.File file;
        private GLib.FileInfo info;

        private enum Type {
            VALID_FILE,
            VALID_FOLDER,
            UNKNOWN,
            INVALID
        }

        public File (string path) {
            file = GLib.File.new_for_path (path);

            info = new FileInfo ();
            try {
                info = file.query_info (
                    GLib.FileAttribute.STANDARD_CONTENT_TYPE + "," +
                    GLib.FileAttribute.STANDARD_IS_BACKUP + "," +
                    GLib.FileAttribute.STANDARD_IS_HIDDEN + "," +
                    GLib.FileAttribute.STANDARD_DISPLAY_NAME + "," +
                    GLib.FileAttribute.STANDARD_TYPE,
                    FileQueryInfoFlags.NONE);
            } catch (GLib.Error error) {
                info = null;
                warning (error.message);
            }
        }

        // returns the path the file
        string _path = null;
        public string path {
            get { return _path != null ? _path : _path = file.get_path (); }
        }

        // returns the basename of the file
        string _name = null;
        public string name {
            get { return _name != null ? _name : _name = info.get_display_name (); }
        }

        // returns the icon of the file's content type
        GLib.Icon _icon = null;
        public GLib.Icon icon {
            get {
                if (_icon != null)
                    return _icon;
                //var content_type = info.get_attribute_string (FileAttribute.STANDARD_FAST_CONTENT_TYPE);
                var content_type = info.get_content_type ();
                return _icon = GLib.ContentType.get_icon (content_type);
            }
        }

        // checks if file exists
        public bool exists {
            get { return file.query_exists (); }
        }

        Type _type = Type.UNKNOWN;
        // checks if we're dealing with a non-hidden, non-backup directory
        public bool is_valid_directory {
            get {
                if (info.get_is_hidden () || info.get_is_backup ()) {
                    return false;
                }

                if (info.get_file_type () == FileType.DIRECTORY) {
                    return true;
                }

                return false;
            }
        }

        // checks if we're dealing with a textfile
        public bool is_valid_textfile {
            get {
                if (_type == Type.VALID_FILE)
                    return true;
                if (_type == Type.VALID_FOLDER)
                    return false;
                if (_type == Type.INVALID)
                    return false;

                if (info.get_file_type () == FileType.REGULAR) {
                    //var content_type = info.get_attribute_string (FileAttribute.STANDARD_FAST_CONTENT_TYPE);
                    var content_type = info.get_content_type ();
                    if (ContentType.is_a (content_type, "text/*") &&
                        !info.get_is_backup () &&
                        !info.get_is_hidden ()) {
                        _type = Type.VALID_FILE;
                        return true;
                    }
                }

                return false;
            }
        }

        // returns a list of all children of a directory
        private Gee.ArrayList <File> _children = new Gee.ArrayList <File> ();
        public Gee.Collection <File> children {
            owned get {
                if (_children.size != 0) {
                    return _children;
                }

                var parent = GLib.File.new_for_path (file.get_path ());
                try {
                    var enumerator = parent.enumerate_children (
                        GLib.FileAttribute.STANDARD_NAME,
                        FileQueryInfoFlags.NONE
                    );

                    var file_info = new FileInfo ();
                    while ((file_info = enumerator.next_file ()) != null) {
                        var child = parent.get_child (file_info.get_name ());
                        var file = new File (child.get_path ());

                        if (file.is_valid_directory || file.is_valid_textfile) {
                            _children.add (new File (child.get_path ()));
                        }
                    }
                } catch (GLib.Error error) {
                    warning (error.message);
                }

                return _children;
            }
        }

        /*public void rename (string name) {
            try {
                file.set_display_name (name);
            } catch (GLib.Error error) {
                warning (error.message);
            }
        }*/

        public void trash () {
            try {
                file.trash ();
            } catch (GLib.Error error) {
                warning (error.message);
            }
        }

        public void reset_cache () {
            _name = null;
            _path = null;
            _icon = null;
            _children.clear ();
            _type = Type.UNKNOWN;
        }

        public static int compare (File a, File b) {
            if (a.is_valid_directory && b.is_valid_textfile)
                return -1;
            if (a.is_valid_textfile && b.is_valid_directory)
                return 1;
            return strcmp (a.path.collate_key_for_filename (),
                           b.path.collate_key_for_filename ());
        }
    }
}
