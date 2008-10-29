import e32
from pyswinst import SwInst

myLock = e32.Ao_lock()

def cb(*args):
    print repr(args)
    myLock.signal()

inst = SwInst()
try:
    inst.install(u"e:\\software\\screenshot_s60_3rd_2.80.sisx", cb)
    myLock.wait()
finally:
    inst.close()

print "all done"
