# 
# Copyright 2007-2008 Helsinki Institute for Information Technology
# (HIIT) and the authors. All rights reserved.
# 
# Authors: Tero Hasu <tero.hasu@hut.fi>
# 

# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import appuifw
import audio
import e32
import os
import fnmatch # not built-in
from pyswinst import SwInst
from miso import FsNotifyChange

def to_unicode(s):
    if type(s) is unicode:
        return s
    return s.decode("utf-8")

def to_str(s):
    if type(s) is str:
        return s
    return s.encode("utf-8")

def path_join(*args):
    # The os. routines, as they are implemented on top of Open C
    # functions, they expect and return UTF-8 encoded strings, while
    # internally we use the "unicode" type. Hence we must convert back
    # and forth.
    ll = [to_str(arg) for arg in args if arg is not None]
    return to_unicode(apply(os.path.join, ll))
    
def scan_files_r(root):
    def g(p):
        pn = path_join(root, p)
        res = []
        for fn in os.listdir(to_str(pn)):
            fn = to_unicode(fn)
            fnp = path_join(pn, fn)
            if os.path.isdir(to_str(fnp)):
                res.extend(g(path_join(p, fn)))
            elif os.path.isfile(to_str(fnp)):
                if fnmatch.fnmatch(fn, "*.sis*"):
                    res.append(fnp)
        return res

    if os.path.isdir(to_str(root)):
        return g(None)
    return []

# Scans the directory for changes. Installs and deletes any files that appear.
class AutoInstaller:
    def __init__(self, inst_dir, cb):
        self.dir = inst_dir
        self.cb = cb
        self.inst = SwInst()
        self.fs = FsNotifyChange()
        self.running = False
        self.cur_fn = None

        self.rescan_files()
        self.fs_observe()

    def send_ev(self, ev_type, msg):
        print msg
        self.cb(ev_type)

    def fs_observe(self):
        self.fs.notify_change(1, self._dir_changed, self.dir)
        
    def _dir_changed(self, error):
        if error == 0:
            self.send_ev("dir_change", "change(s) in directory")
            self.rescan_files()
            self.fs_observe()
            if (not self.cur_fn):
                self.install_next()
        else:
            self.send_ev("fatal_error", "fs notify error %d" % error)

    def rescan_files(self):
        self.files = scan_files_r(self.dir)

    def _sw_installed(self, error):
        fn = self.cur_fn
        self.cur_fn = None
        try:
            self.files.remove(fn)
        except ValueError:
            pass
        if error == 0:
            self.send_ev("inst_ok", "install OK: %s" % fn)
            self.delete_file(fn)
        else:
            self.send_ev("inst_fail", "failed to install %s" % fn)
        self.install_next()

    def delete_file(self, fn):
        try:
            os.unlink(to_str(fn))
            self.send_ev("del_ok", u"deleted %s" % fn)
        except:
            self.send_ev("del_fail", u"failed to delete %s" % fn)
            
    def install_file(self, fn):
        self.send_ev("inst_start", u"installing %s" % fn)
        try:
            self.inst.install(fn, self._sw_installed)
            self.cur_fn = fn
        except:
            self.send_ev("inst_fail", "failed to install %s" % fn)

    def install_next(self):
        if self.running and len(self.files) > 0:
            self.install_file(self.files[0])
        else:
            self.send_ev("no_more", "nothing more to install")

    def start(self):
        if not self.running:
            self.send_ev("started", "auto-installing from: %s" % self.dir)
            self.running = True
            self.install_next()

    def stop(self):
        if self.running:
            self.inst.cancel()
            self.running = False
            self.send_ev("stopped", "auto-installing stopped")

    def close(self):
        self.stop()
        self.fs.close()
        self.inst.close()

class GUI:
    def __init__(self):
        self.lock = e32.Ao_lock()
        self.main_title = u"SwAutoInst"
        self.old_title = appuifw.app.title

        app_path = os.path.split(appuifw.app.full_name())[0]
        self.app_drive = app_path[:2]

        main_menu = [
            (u"Start", self.start),
            (u"Stop", self.stop),
            (u"Exit", self.abort)
            ]

        appuifw.app.title = self.main_title
        appuifw.app.menu = main_menu
        appuifw.app.exit_key_handler = self.abort

        self.installer = AutoInstaller(u"e:\\auto_install", self._inst_event)

    def _inst_event(self, ev_type, **kw):
        if ev_type == "fatal_error":
            self.abort()
        elif ev_type == "inst_ok":
            audio.say("ok")
        elif ev_type == "inst_fail":
            audio.say("failure")

    def start(self):
        self.installer.start()

    def stop(self):
        self.installer.stop()

    def abort(self):
        self.lock.signal()

    def loop(self):
        self.lock.wait()

    def close(self):
        self.installer.close()
        appuifw.app.menu = []
        appuifw.app.exit_key_handler = None
        appuifw.app.title = self.old_title

def main():
    gui = GUI()
    try:
        gui.start()
        gui.loop()
    finally:
        gui.close()

if __name__ == '__main__':
    main()
