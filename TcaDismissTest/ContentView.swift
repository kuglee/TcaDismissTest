import ComposableArchitecture
import SwiftUI

struct ContentView: View {
  var body: some View {
    AppView(
      store: Store(initialState: AppReducer.State(), reducer: { AppReducer()._printChanges() })
    )
  }
}

public struct AppReducer: Reducer {
  public init() {}

  public struct State: Equatable {
    public var childState: Child.State

    public enum Field: Equatable, Hashable { case child(Child.State.EditingState) }

    @BindingState public var focusedField: Field?

    public init(childState: Child.State = .init(), focusedField: Field? = nil) {
      self.childState = childState
      self.focusedField = focusedField
    }
  }

  public enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case childAction(action: Child.Action)
    case wholeViewTapped
  }

  public var body: some ReducerOf<Self> {
    CombineReducers {
      Scope(state: \.childState, action: /Action.childAction) { Child() }

      BindingReducer()

      Reduce { state, action in
        switch action {
        case .binding: return .none
        case .childAction: return .none
        case .wholeViewTapped:
          state.focusedField = nil
          state.childState.editingState = nil

          return .none
        }
      }
    }
    .onChange(of: \.childState.editingState) { _, _ in
      Reduce { state, action in
        guard let editingState = state.childState.editingState else { return .none }

        state.focusedField = .child(editingState)

        return .none
      }
    }
  }
}

public struct AppView: View {
  let store: StoreOf<AppReducer>

  public init(store: StoreOf<AppReducer>) { self.store = store }

  @FocusState var focusedField: AppReducer.State.Field?

  public var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      VStack {
        ChildView(
          store: self.store.scope(state: \.childState, action: AppReducer.Action.childAction)
        )
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).contentShape(Rectangle())
      .onTapGesture { viewStore.send(.wholeViewTapped) }
      .bind(viewStore.$focusedField, to: self.$focusedField)
    }
  }
}

public struct Child: Reducer {
  public init() {}

  public struct State: Equatable {
    public var childItems: IdentifiedArrayOf<PopoverList.State.PopoverListItem>
    @PresentationState public var popoverListState: PopoverList.State?

    public enum EditingState: Equatable { case popover }

    @BindingState public var editingState: EditingState?

    public init(
      childItems: IdentifiedArrayOf<PopoverList.State.PopoverListItem> = [],
      popoverListState: PopoverList.State? = nil,
      editingState: EditingState? = nil
    ) {
      self.childItems = childItems
      self.popoverListState = popoverListState
      self.editingState = editingState
    }
  }

  public enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case childItemsAction(PresentationAction<PopoverList.Action>)
    case gearIconTapped
  }

  public var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding: return .none
      case .childItemsAction: return .none
      case .gearIconTapped:
        state.editingState = .popover
        state.popoverListState = .init(childItems: state.childItems)

        return .none
      }
    }
    .ifLet(\.$popoverListState, action: /Action.childItemsAction) { PopoverList() }
  }
}

public struct ChildView: View {
  let store: StoreOf<Child>

  public init(store: StoreOf<Child>) { self.store = store }

  @FocusState var focusedField: Child.State.EditingState?

  public var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Button(action: { viewStore.send(.gearIconTapped) }) { Image(systemName: "gearshape.fill") }
        .popover(
          store: self.store.scope(state: \.$popoverListState, action: { .childItemsAction($0) }),
          arrowEdge: .trailing
        ) {
          PopoverListView(store: $0).frame(width: 400, height: 200)
            .focused(self.$focusedField, equals: .popover)
        }
        .bind(viewStore.$editingState, to: self.$focusedField)
    }
  }
}

public struct PopoverList: Reducer {
  public init() {}

  public struct State: Equatable {
    public struct PopoverListItem: Equatable, Identifiable {
      public let id: UUID
      public var text: String

      public init(id: UUID, text: String) {
        self.id = id
        self.text = text
      }
    }

    @BindingState public var childItems: IdentifiedArrayOf<PopoverListItem>
    @BindingState public var selectedItemIds: Set<UUID>
    @BindingState var focusedItemId: UUID? = nil

    public init(childItems: IdentifiedArrayOf<PopoverListItem>, selectedItemIds: Set<UUID> = []) {
      self.childItems = childItems
      self.selectedItemIds = selectedItemIds
    }
  }

  public enum Action: Equatable, BindableAction { case binding(BindingAction<State>) }

  public var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding: return .none
      }
    }
  }
}

public struct PopoverListView: View {
  let store: StoreOf<PopoverList>

  public init(store: StoreOf<PopoverList>) { self.store = store }

  public var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      VStack {
        List(selection: viewStore.$selectedItemIds) {
          ForEach(viewStore.$childItems) { $item in TextField("", text: $item.text) }
        }
      }
    }
  }
}
