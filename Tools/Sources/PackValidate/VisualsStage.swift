internal import ContentKit
internal import Foundation
internal import PackReport

/// 시각화 사이드카(`visuals/<id>.json`) 검증 — 구조 단계에 얹힌다.
///
/// **검증기를 새로 쓰지 않는다.** ``VisualFrameSet`` 은 `Decodable` 이면서 디코딩
/// 시점에 의미 검증까지 끝낸다 — 범위 밖 인덱스·없는 노드·빈 자막·프레임 0개가 전부
/// ``VisualFrameSetError`` 로 디코딩 실패가 된다. 그래서 여기서 할 일은 그 디코더를
/// 파일마다 태우고 실패를 리포트 모양으로 옮기는 것뿐이다. 같은 검증을 이 파일에
/// 다시 적으면 두 벌이 되고, 스키마가 자라는 날 한쪽만 따라가다 어긋난다.
///
/// **구조 단계에 붙는 이유**는 실행이 필요 없기 때문이다 — 매니페스트 디코딩·해시
/// 대조와 같은 성격이다. 문법·의미 단계는 레슨 본문(마크다운)을 다루는데, 시각화
/// 사이드카는 레슨 본문과 무관하게 그 자체로 완결된 JSON 이라 본문 파싱을 기다릴
/// 이유가 없다.
///
/// **팩 전체 슬롯에 붙는 이유**는 소유자를 모르기 때문이다. 어느 레슨이 이 사이드카를
/// 쓰는지는 `@Visualize` 디렉티브를 파싱해야 알 수 있고, 구조 단계는 아직 레슨 본문을
/// 열지 않는다 — starters·tests·solutions·expected 사이드카가 팩 전체 슬롯으로 가는
/// 것과 같은 이유다(``StructuralStage``).
enum VisualsStage {
    /// 사이드카가 들어가는 최상위 디렉터리 이름.
    ///
    /// `PackLayout.contentDirectories` 에는 아직 없다 — `visuals` 를 등록 대상
    /// 디렉터리로 받아들이는 일은 매니페스트 스키마 쪽 작업이라 이 검사의 범위 밖이다.
    /// 그래서 매니페스트를 거치지 않고 디스크를 직접 본다: 그 작업이 끝나기 전에도
    /// 독립적으로 돌 수 있고, 끝난 뒤에도 그대로 유효하다.
    static let directoryName = "visuals"

    static func run(pack: ContentPack, into table: inout FailureTable) {
        for failure in failures(in: pack) {
            table.addPackLevel(failure)
        }
    }

    /// `visuals/` 가 아예 없는 팩은 정상이다 — 지금 리포의 팩 전부가 이 모양이다.
    static func failures(in pack: ContentPack) -> [PackValidationReport.Failure] {
        let directory = pack.directory.appendingPathComponent(directoryName, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else { return [] }

        let entries: [URL]
        do {
            entries =
                try FileManager.default.contentsOfDirectory(
                    at: directory, includingPropertiesForKeys: nil
                )
                .filter { $0.pathExtension == "json" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            return [
                failure(
                    summary: "\(directoryName)/ 를 훑을 수 없다",
                    evidence: "\(error)")
            ]
        }

        return entries.flatMap { url in
            failures(at: url, relativePath: "\(directoryName)/\(url.lastPathComponent)")
        }
    }

    private static func failures(
        at url: URL, relativePath: String
    ) -> [PackValidationReport.Failure] {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return [
                failure(summary: "\(relativePath) 를 읽을 수 없다", evidence: "\(error)")
            ]
        }

        let frameSet: VisualFrameSet
        do {
            frameSet = try JSONDecoder().decode(VisualFrameSet.self, from: data)
        } catch let error as VisualFrameSetError {
            // `VisualFrameSetError.description` 이 이미 "frames[2] 의 포인터 `hi`(9) 가
            // 배열 범위 밖이다" 처럼 무엇이 왜 깨졌는지 한국어로 말한다 — 요약은 어느
            // 파일인지만 더하고, 본문은 그대로 증거로 싣는다.
            return [
                failure(
                    summary: "\(relativePath) 이 유효한 시각화 사이드카가 아니다",
                    evidence: "\(error)")
            ]
        } catch {
            // JSON 자체가 깨졌거나(문법 오류) 필드가 통째로 빠진 경우 — 디코더가
            // `VisualFrameSetError` 이전에 던지는 일반 `DecodingError` 다.
            return [
                failure(
                    summary: "\(relativePath) 을 디코딩할 수 없다",
                    evidence: "\(error)")
            ]
        }

        // 레슨의 `@Visualize` 디렉티브가 `id` 값으로 사이드카 파일을 찾는다. 파일 이름과
        // id 가 어긋나면 디코딩 자체는 성공해도 그 레슨은 영영 이 파일을 찾지 못한다.
        let expectedFileName = "\(frameSet.id).json"
        guard url.lastPathComponent == expectedFileName else {
            return [
                failure(
                    summary: "\(relativePath) 의 id `\(frameSet.id)` 가 파일 이름과 다르다",
                    evidence: "레슨이 이 id 로 찾는 파일 이름은 \(expectedFileName) 이어야 한다")
            ]
        }
        return []
    }

    private static func failure(summary: String, evidence: String) -> PackValidationReport.Failure {
        PackValidationReport.Failure(
            stage: .structural,
            kind: .brokenReference,
            summary: summary,
            evidence: evidence
        )
    }
}
