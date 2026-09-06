/// 표준 `unittest` 위에 얹는 JSON Lines 리포터.
///
/// **pytest 를 쓰지 않는다.** 이 머신에도, 학습자 대부분의 머신에도 pytest 는 없고,
/// `-I`(격리 모드)로 도는 인터프리터는 사용자 site-packages 를 아예 보지 않으므로
/// 설치돼 있어도 못 쓴다. 표준 라이브러리만으로 통과·실패·에러 세 종류를 가른다.
///
/// **결과를 stdout 이 아니라 파일로 낸다.** 사용자 코드의 `print` 가 같은 stdout 을
/// 쓰기 때문이다 — 한 줄만 섞여도 JSON 파서가 무너지고, 그 실패는 "학습자 코드가
/// 이상하다"로 잘못 읽힌다. 출력 경로는 워크스페이스 **바깥**이라 실행이 끝나고
/// 워크스페이스가 지워진 뒤에도 채점기가 읽을 수 있다.
enum PythonUnittestHarness {
    /// 워크스페이스에 함께 놓이는 하네스 파일 이름.
    static let fileName = "__learnkit_harness.py"

    /// `python3 -I -B __learnkit_harness.py <출력경로> <테스트모듈...>`
    static let source = #"""
# learnkit unittest → JSON Lines 리포터. 표준 라이브러리만 쓴다.
import importlib
import json
import os
import sys
import time
import traceback
import unittest

MAX_MESSAGE = 4000


def _display_name(test):
    try:
        method = getattr(test, "_testMethodName", None)
        if method:
            return "%s.%s" % (type(test).__name__, method)
    except Exception:
        pass
    return str(test)


def _describe(err, full):
    kind, value, tb = err
    if full:
        text = "".join(traceback.format_exception(kind, value, tb))
    else:
        text = "".join(traceback.format_exception_only(kind, value))
    text = text.strip()
    if len(text) > MAX_MESSAGE:
        text = text[:MAX_MESSAGE] + "\n… (잘림)"
    return text


class JSONRecorder(unittest.TestResult):
    def __init__(self):
        super().__init__()
        self.records = []
        self._started = {}
        self._closed = set()

    def startTest(self, test):
        super().startTest(test)
        self._started[id(test)] = time.monotonic()

    def _close(self, test, status, message):
        key = id(test)
        if key in self._closed:
            return
        self._closed.add(key)
        began = self._started.get(key, time.monotonic())
        self.records.append({
            "name": _display_name(test),
            "status": status,
            "message": message,
            "durationMilliseconds": int((time.monotonic() - began) * 1000),
        })

    def addSuccess(self, test):
        super().addSuccess(test)
        self._close(test, "passed", None)

    # 단언 실패와 예외는 학습자에게 다른 뜻이다 — "답이 틀렸다" 와 "코드가 터졌다".
    def addFailure(self, test, err):
        super().addFailure(test, err)
        self._close(test, "failed", _describe(err, False))

    def addError(self, test, err):
        super().addError(test, err)
        self._close(test, "error", _describe(err, True))

    def addSkip(self, test, reason):
        super().addSkip(test, reason)
        self._close(test, "skipped", reason)

    def addExpectedFailure(self, test, err):
        super().addExpectedFailure(test, err)
        self._close(test, "passed", None)

    def addUnexpectedSuccess(self, test):
        super().addUnexpectedSuccess(test)
        self._close(test, "failed", "실패를 예상한 테스트가 통과했다")


def _load(names):
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    for name in names:
        module_name = name[:-3] if name.endswith(".py") else name
        try:
            module = importlib.import_module(module_name)
        except BaseException:
            # 임포트 실패도 결과다. 하네스가 죽으면 학습자는 아무것도 못 본다.
            suite.addTest(_ImportFailure(module_name, traceback.format_exc()))
            continue
        suite.addTests(loader.loadTestsFromModule(module))
    return suite


class _ImportFailure(unittest.TestCase):
    def __init__(self, module_name, detail):
        super().__init__("runTest")
        self._module_name = module_name
        self._detail = detail

    def runTest(self):
        raise ImportError("%s 를 불러오지 못했다:\n%s" % (self._module_name, self._detail))

    def __str__(self):
        return "import(%s)" % self._module_name


def main():
    if len(sys.argv) < 3:
        sys.stderr.write("usage: harness.py <json-out> <test-module>...\n")
        return 2
    out_path = sys.argv[1]
    names = sys.argv[2:]

    # `-I` 는 스크립트 디렉터리를 sys.path 에 넣지 않는다(-P). 사용자 모듈과 숨은
    # 테스트를 임포트하려면 여기서 직접 넣어야 한다 — 격리는 유지하면서 워크스페이스
    # 하나만 열어 주는 셈이다.
    here = os.path.dirname(os.path.abspath(__file__))
    if here not in sys.path:
        sys.path.insert(0, here)

    suite = _load(names)
    recorder = JSONRecorder()
    began = time.monotonic()
    suite.run(recorder)
    elapsed = int((time.monotonic() - began) * 1000)

    passed = all(record["status"] in ("passed", "skipped") for record in recorder.records)
    lines = [json.dumps({"kind": "test", **record}, ensure_ascii=False) for record in recorder.records]
    lines.append(json.dumps({
        "kind": "summary",
        "passed": passed and len(recorder.records) > 0,
        "count": len(recorder.records),
        "durationMilliseconds": elapsed,
    }, ensure_ascii=False))
    with open(out_path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
"""#
}
