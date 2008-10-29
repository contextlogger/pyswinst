#include <e32std.h>
#include <swinstapi.h>

#include <Python.h>
#include <symbian_python_ext_util.h>
#include "local_epoc_py_utils.h"

// -------------------------------------------------------
// C++ instance...

/* As installation can be slow, we should probably have an active object to take care of the installation, also on the Python side. So no mere "install" module method for us here. We could use an internal wait loop, though, I guess, but this approach is more flexible. */

NONSHARABLE_CLASS(CSwInstAo) : public CActive
{
public:
  
  static CSwInstAo *NewLC();
  
  static CSwInstAo *NewL();
  
private:
  
  void ConstructL();
  
  CSwInstAo();
  
public:
  
  ~CSwInstAo();
  
private:
  
  void RunL();
  
  void DoCancel();
  
public:
  
  /** @param aCallback A callable to call when the installation has succeeded, or otherwise completed. An error code is passed to the callback as a sole argument.
      @param aFileName Path to the installation package. (May be freed after invoking InstallL.)
      @param aOptions Options for installation. Package with TInstallOptionsPckg. (May be freed after invoking InstallL.)
   */
  void InstallL(PyObject *aCallback, TDesC const &aFileName, TDesC8 const &aOptions);
  
private:
  
  SwiUI::RSWInstSilentLauncher iLauncher;
  
  HBufC* iFileName;
  HBufC8* iOptions;
  PyObject *iCallback;
};

CSwInstAo *CSwInstAo::NewLC()
{
  CSwInstAo *object = new (ELeave) CSwInstAo();
  CleanupStack::PushL(object);
  object->ConstructL();
  return object;
}

CSwInstAo *CSwInstAo::NewL()
{
  CSwInstAo *object = NewLC();
  CleanupStack::Pop();
  return object;
}

void CSwInstAo::ConstructL()
{
  User::LeaveIfError(iLauncher.Connect());
}

CSwInstAo::CSwInstAo() : CActive(EPriorityStandard)
{
  CActiveScheduler::Add(this);
}

CSwInstAo::~CSwInstAo()
{
  if ((iLauncher.Handle() != 0)) {
    iLauncher.Close();
  }
  delete iFileName;
  delete iOptions;
  Py_XDECREF(iCallback);
}

void CSwInstAo::RunL()
{
  TInt error = iStatus.Int();
  PyEval_RestoreThread(PYTHON_TLS->thread_state);
  PyObject *callarg = Py_BuildValue("(i)", error);
  if (callarg) {
    PyObject *result = PyObject_CallObject(iCallback, callarg);
    Py_DECREF(callarg);
    Py_XDECREF(result);
  }
  PyEval_SaveThread();
}

void CSwInstAo::DoCancel()
{
  // ignoring undocumented TInt return code
  iLauncher.CancelAsyncRequest(SwiUI::ERequestSilentInstall);
}

void CSwInstAo::InstallL(PyObject *aCallback, TDesC const &aFileName, TDesC8 const &aOptions)
{
  if (IsActive()) {
    Cancel();
  }

  if (iFileName) {
    delete iFileName;
    iFileName = NULL;
  }
  // Not documented if RSWInstSilentLauncher creates a copy.
  iFileName = aFileName.AllocL();

  if (iOptions) {
    delete iOptions;
    iOptions = NULL;
  }
  // Not documented if RSWInstSilentLauncher creates a copy.
  iOptions = aOptions.AllocL();

  Py_XDECREF(iCallback);
  (iCallback = aCallback);
  Py_INCREF(aCallback);

  iLauncher.SilentInstall(iStatus, *iFileName, *iOptions);

  SetActive();
}

// -------------------------------------------------------
// Python instance declaration...

struct _or__pyswinst__SwInst
{
  PyObject_VAR_HEAD;
  
  CSwInstAo *iCxxObjPtr;
};

static PyObject *_ctor__pyswinst__SwInst(PyObject *aPyMod, PyObject *aPyArgs);

static PyObject *_fn__pyswinst__SwInst__install(_or__pyswinst__SwInst *aPyObj, PyObject *aPyArgs);

static PyObject *_fn__pyswinst__SwInst__cancel(_or__pyswinst__SwInst *aPyObj, PyObject *aPyArgs);

static PyObject *_fn__pyswinst__SwInst__close(_or__pyswinst__SwInst *aPyObj, PyObject *aPyArgs);

static void del_SwInst(_or__pyswinst__SwInst *aPyObj);

static PyObject *getattr_SwInst(PyObject *aPyObj, char *aName);

static PyTypeObject const tmpl_SwInst = {PyObject_HEAD_INIT(NULL) 0, "pyswinst.SwInst", sizeof(_or__pyswinst__SwInst), 0, reinterpret_cast<destructor>(del_SwInst), 0, reinterpret_cast<getattrfunc>(getattr_SwInst), 0, 0, 0, 0, 0, 0, 0};

static TInt def_SwInst();

static PyMethodDef const _mt__pyswinst__SwInst[] = {{"install", reinterpret_cast<PyCFunction>(_fn__pyswinst__SwInst__install), METH_VARARGS, NULL}, {"cancel", reinterpret_cast<PyCFunction>(_fn__pyswinst__SwInst__cancel), METH_NOARGS, NULL}, {"close", reinterpret_cast<PyCFunction>(_fn__pyswinst__SwInst__close), METH_NOARGS, NULL}, {NULL}};

// -------------------------------------------------------
// Python instance implementation...

static PyObject *_ctor__pyswinst__SwInst(PyObject *aPyMod, PyObject *aPyArgs)
{
  PyTypeObject *typeObject = reinterpret_cast<PyTypeObject *>(SPyGetGlobalString(tmpl_SwInst.tp_name));
  _or__pyswinst__SwInst *pyObj = PyObject_New(_or__pyswinst__SwInst, typeObject);
  if ((pyObj == NULL)) {
    return NULL;
  }
  (pyObj->iCxxObjPtr = NULL);
  TInt error;
  TRAP(error, (pyObj->iCxxObjPtr = CSwInstAo::NewL()););
  if (error) {
    PyObject_Del(pyObj);
    return SPyErr_SetFromSymbianOSErr(error);
  }
  return reinterpret_cast<PyObject *>(pyObj);
}

static PyObject *_fn__pyswinst__SwInst__install(_or__pyswinst__SwInst *aPyObj, PyObject *aPyArgs)
{
  TUint16 *mPtr;
  int mLen;
  PyObject *cb;
  if ((!PyArg_ParseTuple(aPyArgs, "u#O", (&mPtr), (&mLen), (&cb)))) {
    return NULL;
  }
  if ((!PyCallable_Check(cb))) {
    PyErr_SetString(PyExc_TypeError, "argument must be callable");
    return NULL;
  }
  TPtrC fileName(mPtr, mLen);

  SwiUI::TInstallOptions opts;
  opts.iUpgrade = SwiUI::EPolicyAllowed;
  opts.iOCSP = SwiUI::EPolicyNotAllowed;
  opts.iDrive = 'E';
  opts.iUntrusted = SwiUI::EPolicyAllowed; 
  opts.iCapabilities = SwiUI::EPolicyNotAllowed; 
  opts.iKillApp = SwiUI::EPolicyAllowed; 
  opts.iUpgradeData = SwiUI::EPolicyNotAllowed; 
  opts.iOverwrite = SwiUI::EPolicyAllowed; 
  opts.iDownload = SwiUI::EPolicyNotAllowed; 
  opts.iPackageInfo = SwiUI::EPolicyAllowed; 

  SwiUI::TInstallOptionsPckg optsPckg;
  optsPckg = opts;

  TInt error;
  TRAP(error, (aPyObj->iCxxObjPtr->InstallL(cb, fileName, optsPckg)););
  if (error) {
    return SPyErr_SetFromSymbianOSErr(error);
  }
  RETURN_NO_VALUE;
}

static PyObject *_fn__pyswinst__SwInst__cancel(_or__pyswinst__SwInst *aPyObj, PyObject *aPyArgs)
{
  aPyObj->iCxxObjPtr->Cancel();
  RETURN_NO_VALUE;
}

// As you see here, doing anything but "close" after doing a "close" is a no-no.
static PyObject *_fn__pyswinst__SwInst__close(_or__pyswinst__SwInst *aPyObj, PyObject *aPyArgs)
{
  (delete aPyObj->iCxxObjPtr);
  (aPyObj->iCxxObjPtr = NULL);
  RETURN_NO_VALUE;
}

static void del_SwInst(_or__pyswinst__SwInst *aPyObj)
{
  (delete aPyObj->iCxxObjPtr);
  (aPyObj->iCxxObjPtr = NULL);
  PyObject_Del(aPyObj);
}

static PyObject *getattr_SwInst(PyObject *aPyObj, char *aName)
{
  return Py_FindMethod(const_cast<PyMethodDef *>((&_mt__pyswinst__SwInst[0])), aPyObj, aName);
}

static TInt def_SwInst()
{
  return ConstructType((&tmpl_SwInst), tmpl_SwInst.tp_name);
}

// -------------------------------------------------------
// Python module...

static PyMethodDef const _ft__pyswinst[] = {{"SwInst", reinterpret_cast<PyCFunction>(_ctor__pyswinst__SwInst), METH_NOARGS, NULL}, {NULL}};

EXPORT_C void initpyswinst()
{
  PyObject *pyMod = Py_InitModule("pyswinst", const_cast<PyMethodDef *>((&_ft__pyswinst[0])));
  if ((pyMod == NULL)) {
    return;
  }
  if ((def_SwInst() < 0)) {
    return;
  }
}

#ifndef EKA2
GLDEF_C TInt E32Dll(TDllReason)
{
  return KErrNone;
}
#endif
