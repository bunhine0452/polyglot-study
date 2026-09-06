import LLMKit
import Testing

@Suite("모델 선택 — 기본과 단계별 오버라이드")
struct ModelSelectionTests {
    @Test("기본 모델이 없으면 던진다 — 조용한 기본값을 두지 않는다")
    func baseModelIsRequired() {
        #expect(throws: ModelIDError.notSet) { try ModelID.fromEnvironment([:]) }
        #expect(throws: ModelIDError.empty) { try ModelID.fromEnvironment(["OPENROUTER_MODEL": "  "]) }
        #expect(throws: ModelIDError.notSet) { try ModelSelection.fromEnvironment([:]) }
    }

    @Test("미설정 안내가 왜 기본값이 없는지 말해 준다")
    func guidanceExplainsWhy() {
        let message = String(describing: ModelIDError.notSet)
        #expect(message.contains("OPENROUTER_MODEL"))
        #expect(message.contains("--model"))
    }

    @Test("오버라이드가 없으면 모든 단계가 기본 모델을 쓴다")
    func allStagesFallBackToBase() throws {
        let selection = try ModelSelection.fromEnvironment(["OPENROUTER_MODEL": "vendor/base"])
        for stage in GenerationStage.allCases {
            #expect(selection.model(for: stage) == ModelID("vendor/base"))
            #expect(selection.origin(for: stage) == "OPENROUTER_MODEL")
        }
    }

    @Test("단계별 환경변수가 그 단계만 덮는다")
    func stageOverride() throws {
        let selection = try ModelSelection.fromEnvironment([
            "OPENROUTER_MODEL": "vendor/cheap",
            "OPENROUTER_MODEL_PROSE": "vendor/careful",
        ])
        #expect(selection.model(for: .prose) == ModelID("vendor/careful"))
        #expect(selection.origin(for: .prose) == "OPENROUTER_MODEL_PROSE")
        #expect(selection.model(for: .lesson) == ModelID("vendor/cheap"))
        #expect(selection.origin(for: .lesson) == "OPENROUTER_MODEL")
    }

    @Test("네 단계 전부 각자의 변수 이름을 갖는다")
    func everyStageHasAVariable() {
        let names = GenerationStage.allCases.map(\.environmentVariableName)
        #expect(
            names == [
                "OPENROUTER_MODEL_OUTLINE",
                "OPENROUTER_MODEL_LESSON",
                "OPENROUTER_MODEL_PROSE",
                "OPENROUTER_MODEL_REPAIR",
            ]
        )
        #expect(Set(names).count == names.count)
    }

    /// 이 분할의 존재 이유를 못 박는다. 게이트가 없는 단계와 있는 단계가 **서로 다른
    /// 모델로 갈 수 있어야** 한다 — 컴파일되는 코드 옆의 틀린 설명은 어떤 자동 검사도
    /// 잡지 못하기 때문이다.
    @Test("게이트 없는 단계와 있는 단계를 다른 모델로 보낼 수 있다")
    func ungatedStagesCanUseADifferentModel() throws {
        let selection = try ModelSelection.fromEnvironment([
            "OPENROUTER_MODEL": "vendor/cheap",
            "OPENROUTER_MODEL_PROSE": "vendor/careful",
            "OPENROUTER_MODEL_OUTLINE": "vendor/careful",
        ])
        let ungated = GenerationStage.allCases.filter { !$0.isMachineVerified }
        let gated = GenerationStage.allCases.filter(\.isMachineVerified)

        #expect(!ungated.isEmpty)
        #expect(!gated.isEmpty)
        for stage in ungated { #expect(selection.model(for: stage) == ModelID("vendor/careful")) }
        for stage in gated { #expect(selection.model(for: stage) == ModelID("vendor/cheap")) }
    }

    @Test("packtool 이 실행 검증하는 단계만 machine-verified 다")
    func gateClassification() {
        #expect(GenerationStage.lesson.isMachineVerified)
        #expect(GenerationStage.repair.isMachineVerified)
        // 개요는 사람이, 산문은 아무도 검증하지 않는다.
        #expect(!GenerationStage.outline.isMachineVerified)
        #expect(!GenerationStage.prose.isMachineVerified)
    }

    @Test("--model 은 기본만 덮고 단계별 설정은 살려 둔다")
    func flagOverridesBaseOnly() throws {
        let selection = try ModelSelection.fromEnvironment(
            ["OPENROUTER_MODEL": "vendor/from-env", "OPENROUTER_MODEL_PROSE": "vendor/careful"],
            override: ModelID("vendor/from-flag")
        )
        #expect(selection.model(for: .lesson) == ModelID("vendor/from-flag"))
        #expect(selection.model(for: .prose) == ModelID("vendor/careful"))
    }

    @Test("--model 을 주면 환경변수가 없어도 돌아간다")
    func flagAloneIsEnough() throws {
        let selection = try ModelSelection.fromEnvironment([:], override: ModelID("vendor/only-flag"))
        #expect(selection.base == ModelID("vendor/only-flag"))
    }

    @Test("빈 오버라이드는 무시한다")
    func emptyOverrideIgnored() throws {
        let selection = try ModelSelection.fromEnvironment([
            "OPENROUTER_MODEL": "vendor/base",
            "OPENROUTER_MODEL_PROSE": "   ",
        ])
        #expect(selection.model(for: .prose) == ModelID("vendor/base"))
    }

    @Test("실행 로그 한 줄에 네 단계가 전부 담긴다 — 나중에 누가 썼는지 되짚게")
    func logLineNamesEveryStage() throws {
        let selection = try ModelSelection.fromEnvironment([
            "OPENROUTER_MODEL": "vendor/base",
            "OPENROUTER_MODEL_PROSE": "vendor/careful",
        ])
        let line = selection.logLine
        for stage in GenerationStage.allCases {
            #expect(line.contains("\(stage.rawValue)=\(selection.model(for: stage).rawValue)"))
        }
        #expect(line.contains("prose=vendor/careful"))
    }
}
