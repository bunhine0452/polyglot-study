internal import DesignSystem
internal import LearnCore
internal import SwiftUI

/// **자이가르닉 효과** — 멈춘 레슨을 화면 최상단에 열어 둔다.
///
/// 이 카드가 화면의 첫 블록인 것 자체가 설계다. 완료된 것을 축하하는 자리가 아니라
/// *끝나지 않은 것*을 보여 주는 자리이고, 블록 진도 막대에서 진행 중 블록은 채우지 않고
/// 빈 윤곽으로 남긴다(`ResumePoint.blockCells`) — 그 한 칸이 미완성 긴장을 만든다.
struct OpenLessonCard: View {
    let resume: ResumePoint?
    let onResume: (ResumePoint) -> Void

    var body: some View {
        DashboardCard(label: "이어서 · 열린 레슨") {
            if let resume {
                filled(resume)
            } else {
                empty
            }
        }
    }

    @ViewBuilder
    private func filled(_ resume: ResumePoint) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(resume.lessonTitle)
                .font(AppFont.sans(.title, weight: .semibold))
                .tracking(-0.24)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            stoppedAtLine(resume)
        }

        HStack(spacing: DashboardLayout.cardSpacing) {
            SegmentedProgress(resume.blockCells, height: .slim)
                .frame(maxWidth: DashboardLayout.blockBarMaxWidth)
            LabelText("\(resume.completedBlocks) / \(LessonBlockSequence.count) 블록")
                .fixedSize()
        }

        HStack(spacing: Spacing.m) {
            FlatButton("이어서 하기", shortcutHint: "↩") { onResume(resume) }
            Text("남은 블록 \(resume.remainingBlocks) · 약 \(resume.remainingMinutes)분")
                .font(AppFont.sans(.label))
                .foregroundStyle(Palette.faint)
        }
        .padding(.top, Spacing.xs)
    }

    /// "Swift · 레슨 07 / 24 · 4번째 블록 **테스트 과제**에서 멈춤".
    /// 멈춘 지점만 잉크로 올려 눈이 거기 걸리게 한다.
    private func stoppedAtLine(_ resume: ResumePoint) -> some View {
        let head: String = if let ordinal = resume.lessonOrdinal {
            "\(resume.trackName) · 레슨 \(ordinal) / \(resume.lessonTotal) · \(resume.blockIndex + 1)번째 블록 "
        } else {
            "\(resume.trackName) · \(resume.blockIndex + 1)번째 블록 "
        }
        let block = resume.blockName ?? ""
        return (
            Text(head).foregroundStyle(Palette.secondary)
                + Text(block).foregroundStyle(Palette.ink).fontWeight(.medium)
                + Text("에서 멈춤").foregroundStyle(Palette.secondary)
        )
        .font(AppFont.sans(.label))
    }

    /// 열린 레슨이 없는 상태. 없는 긴장을 지어내지 않는다 — 무엇이 없는지만 말한다.
    private var empty: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("열린 레슨 없음")
                .font(AppFont.sans(.title, weight: .semibold))
                .tracking(-0.24)
                .foregroundStyle(Palette.faint)
            Text("트랙에서 레슨을 열면 멈춘 자리가 여기 남습니다.")
                .font(AppFont.sans(.label))
                .foregroundStyle(Palette.secondary)
        }
    }
}

/// 2단 카드 한 칸의 공통 크롬 — 상단 굵은 룰, 14px 여백, 라벨, 12px 간격.
struct DashboardCard<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DashboardLayout.cardSpacing) {
            LabelText(label)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DashboardLayout.cardTopPadding)
        .overlay(alignment: .top) { Rule(.hard) }
    }
}
