import Combine
import Foundation

/// 진행 선택(U5)과 커스텀(U6)이 **한 라이브러리를 공유**하도록 묶는 작은 컨테이너.
///
/// 이렇게 묶어야 커스텀에서 만든 진행이 선택 화면 목록에 바로 나타난다. `AppRootView`가
/// 이걸 하나 들고 두 화면에 각각의 뷰모델을 나눠준다.
@MainActor
final class ProgressionFlowModel: ObservableObject {
    private let library = ChordProgressionLibrary()

    let select: ProgressionSelectViewModel
    let custom: ProgressionCustomViewModel

    init() {
        select = ProgressionSelectViewModel(library: library)
        custom = ProgressionCustomViewModel(library: library)
    }
}
