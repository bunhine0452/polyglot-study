/// 팩 디렉터리 레이아웃 v1. `docs/pack-format.md` 와 이 파일이 같은 것을 말해야 한다.
///
/// ```
/// <pack>/
///   manifest.json          팩 메타데이터 (스키마 v1). files 에 자기 자신은 넣지 않는다.
///   manifest.json.sig      정규 매니페스트 바이트에 대한 분리 서명 (packtool sign)
///   stableids.lock         stableID 불변 잠금 파일
///   lessons/    <id>.md    디렉티브 마크다운 레슨 본문
///   starters/   <path>     과제 시작 코드 (학습자에게 주어지는 것)
///   tests/      <path>     숨은 테스트 (채점기가 돌리는 것)
///   solutions/  <path>     정답 코드 (배포 팩에서는 벗겨진다)
///   expected/   <id>.txt   실행 예제의 기대 stdout
///   assets/     <path>     이미지·샘플 DB 등 읽기 전용 자원
///   visuals/    <id>.json  알고리즘 시각화 프레임({#visualize-directive})
/// ```
public enum PackLayout {
    public static let manifestFileName = "manifest.json"
    /// 분리 서명. 매니페스트 **뒤에** 만들어지므로 `files` 에 들어갈 수 없다.
    public static let signatureFileName = "manifest.json.sig"
    public static let lockFileName = "stableids.lock"

    public static let lessonsDirectory = "lessons"
    public static let startersDirectory = "starters"
    public static let testsDirectory = "tests"
    public static let solutionsDirectory = "solutions"
    public static let expectedDirectory = "expected"
    public static let assetsDirectory = "assets"
    /// 시각화 프레임 사이드카. 파일 이름이 곧 `@Visualize` 가 찾는 id 다.
    public static let visualsDirectory = "visuals"

    /// `files` 에 등록될 수 있는 최상위 디렉터리 7종. 이 밖의 위치는 검증에서 거부된다.
    public static let contentDirectories: [String] = [
        lessonsDirectory, startersDirectory, testsDirectory,
        solutionsDirectory, expectedDirectory, assetsDirectory, visualsDirectory,
    ]

    /// 최상위에 그냥 놓일 수 있는 파일. `manifest.json` 은 자기 해시를 담을 수 없으므로
    /// `files` 에 등록되지 않고, 나머지는 등록된다.
    public static let rootFiles: [String] = [lockFileName]

    /// `files` 에 **등록되지 않는** 루트 파일 둘. 스캐너가 여기를 건너뛴다.
    ///
    /// 자기 참조라 등록될 수 없다는 점이 같다 — 매니페스트는 자기 해시를 담을 수 없고,
    /// 서명은 그 매니페스트가 확정된 다음에야 만들어진다. 이 둘을 건너뛰지 않으면
    /// 양방향 대조가 "디스크에 있는데 files 에 없다" 로 팩을 거부한다.
    public static let unregisteredRootFiles: [String] = [manifestFileName, signatureFileName]

    /// 배포 팩에서 벗겨지는 디렉터리. `packtool build` 가 여기를 지운다.
    public static let strippedInDistribution: [String] = [solutionsDirectory]

    /// 경로가 레이아웃 안에 있는가. `files` 등록 자격 검사.
    public static func isRegisterable(_ path: PackRelativePath) -> Bool {
        if let directory = path.topLevelDirectory {
            return contentDirectories.contains(directory)
        }
        return rootFiles.contains(path.rawValue)
    }
}
