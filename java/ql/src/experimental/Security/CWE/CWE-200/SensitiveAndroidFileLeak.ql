/**
 * @name Leaking sensitive Android file
 * @description Using a path specified in an Android Intent without validation could leak arbitrary
 *              Android configuration file and sensitive user data.
 * @kind path-problem
 * @id java/sensitive-android-file-leak
 * @problem.severity warning
 * @tags security
 *       experimental
 *       external/cwe/cwe-200
 */

import java
import semmle.code.java.controlflow.Guards
deprecated import AndroidFileIntentSink
deprecated import AndroidFileIntentSource
deprecated import AndroidFileLeakFlow::PathGraph

private predicate startsWithSanitizer(Guard g, Expr e, boolean branch) {
  exists(MethodCall ma |
    g = ma and
    ma.getMethod().hasName("startsWith") and
    e = [ma.getQualifier(), ma.getQualifier().(MethodCall).getQualifier()] and
    branch = false
  )
}

deprecated module AndroidFileLeakConfig implements DataFlow::ConfigSig {
  /**
   * Holds if `src` is a read of some Intent-typed variable guarded by a check like
   * `requestCode == someCode`, where `requestCode` is the first
   * argument to `Activity.onActivityResult` and `someCode` is
   * any request code used in a call to `startActivityForResult(intent, someCode)`.
   */
  predicate isSource(DataFlow::Node src) {
    exists(
      OnActivityForResultMethod oafr, ConditionBlock cb, CompileTimeConstantExpr cc,
      VarAccess intentVar
    |
      cb.getCondition()
          .(ValueOrReferenceEqualsExpr)
          .hasOperands(oafr.getParameter(0).getAnAccess(), cc) and
      cc.getIntValue() = any(AndroidFileIntentInput fi).getRequestCode() and
      intentVar.getType() instanceof TypeIntent and
      cb.controls(intentVar.getBasicBlock(), true) and
      src.asExpr() = intentVar
    )
  }

  /** Holds if it is a sink of file access in Android. */
  predicate isSink(DataFlow::Node sink) { sink instanceof AndroidFileSink }

  predicate isAdditionalFlowStep(DataFlow::Node prev, DataFlow::Node succ) {
    exists(MethodCall aema, AsyncTaskRunInBackgroundMethod arm |
      // fileAsyncTask.execute(params) will invoke doInBackground(params) of FileAsyncTask
      aema.getQualifier().getType() = arm.getDeclaringType() and
      aema.getMethod() instanceof ExecuteAsyncTaskMethod and
      prev.asExpr() = aema.getArgument(aema.getMethod().(ExecuteAsyncTaskMethod).getParamIndex()) and
      succ.asParameter() = arm.getParameter(0)
    )
    or
    exists(MethodCall csma, ServiceOnStartCommandMethod ssm, ClassInstanceExpr ce |
      // An intent passed to startService will later be passed to the onStartCommand event of the corresponding service
      csma.getMethod() instanceof ContextStartServiceMethod and
      ce.getConstructedType() instanceof TypeIntent and // Intent intent = new Intent(context, FileUploader.class);
      ce.getArgument(1).(TypeLiteral).getReferencedType() = ssm.getDeclaringType() and
      DataFlow::localExprFlow(ce, csma.getArgument(0)) and // context.startService(intent);
      prev.asExpr() = csma.getArgument(0) and
      succ.asParameter() = ssm.getParameter(0) // public int onStartCommand(Intent intent, int flags, int startId) {...} in FileUploader
    )
  }

  predicate isBarrier(DataFlow::Node node) {
    node = DataFlow::BarrierGuard<startsWithSanitizer/3>::getABarrierNode()
  }
}

deprecated module AndroidFileLeakFlow = TaintTracking::Global<AndroidFileLeakConfig>;

deprecated query predicate problems(
  DataFlow::Node sinkNode, AndroidFileLeakFlow::PathNode source, AndroidFileLeakFlow::PathNode sink,
  string message1, DataFlow::Node sourceNode, string message2
) {
  AndroidFileLeakFlow::flowPath(source, sink) and
  sinkNode = sink.getNode() and
  message1 = "Leaking arbitrary Android file from $@." and
  sourceNode = source.getNode() and
  message2 = "this user input"
}
