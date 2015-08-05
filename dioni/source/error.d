module error;
class CompileError : Exception {
	@safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) {
		super("CompileError"~msg, file, line, next);
	}
}
