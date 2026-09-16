import SwiftUI

struct CalendarSubscriptionsSettingsView: View {
    @ObservedObject var store: CalendarSubscriptionStore
    @ViewState private var addingSubscription = false

    var body: some View {
        Form {
            Section {
                ForEach(store.subscriptions) { subscription in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Toggle(subscription.title, isOn: Binding(
                                get: { subscription.isEnabled },
                                set: { store.setEnabled($0, id: subscription.id) }
                            ))
                            .lineLimit(2)
                            Spacer(minLength: 0)
                            if store.refreshing.contains(subscription.id) {
                                ProgressView().controlSize(.small)
                            } else {
                                Button {
                                    Task { await store.refresh(id: subscription.id, force: true) }
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                }
                                .help("刷新\(subscription.title)")
                                .accessibilityLabel("刷新\(subscription.title)")
                            }
                            if !subscription.isBuiltIn {
                                Button(role: .destructive) {
                                    store.remove(id: subscription.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .help("删除\(subscription.title)")
                                .accessibilityLabel("删除\(subscription.title)")
                            }
                        }
                        if let error = store.errors[subscription.id] {
                            Text(error + (store.lastUpdated(subscription.id) == nil ? "" : " 当前显示上次同步的内容。"))
                                .foregroundStyle(.orange)
                                .font(.caption)
                        }
                        HStack {
                            Text(subscription.isBuiltIn ? "来源：Apple 中国大陆节假日日历" : subscription.url.host ?? "订阅日历")
                            Spacer()
                            if let date = store.lastUpdated(subscription.id) {
                                Text(date, format: .dateTime.month().day().hour().minute())
                                Text("已更新")
                            } else {
                                Text("尚未同步")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                }
                HStack {
                    Button("添加订阅…", systemImage: "plus") { addingSubscription = true }
                    Spacer()
                    Button("全部刷新") { Task { await store.refreshAll(force: true) } }
                        .disabled(!store.refreshing.isEmpty)
                }
                if let error = store.persistenceError {
                    Text(error).font(.caption).foregroundStyle(.orange)
                }
            } header: {
                Text("已订阅的日历")
            } footer: {
                Text("订阅在 MenuCal 内管理，无需系统日历权限。使用时每 6 小时刷新，离线保留上次内容。节假日与调休以 Apple 已发布的数据为准。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $addingSubscription) {
            AddCalendarSubscriptionView(store: store)
        }
        .task { await store.refreshAll() }
    }
}

private struct AddCalendarSubscriptionView: View {
    @ObservedObject var store: CalendarSubscriptionStore
    @Environment(\.dismiss) private var dismiss
    @ViewState private var title = ""
    @ViewState private var address = ""
    @ViewState private var error: String?
    @ViewState private var isAdding = false
    @ViewState private var addTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("添加日历订阅").font(.headline)
            Text("粘贴日历服务提供的 ICS 订阅链接。订阅为只读，内容保存在这台 Mac 上。")
                .font(.callout).foregroundStyle(.secondary)
            TextField("名称（可选）", text: $title)
            TextField("https:// 或 webcal:// 订阅链接", text: $address)
                .onSubmit(add)
            if let error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
            HStack {
                if isAdding { ProgressView().controlSize(.small); Text("正在验证日历…").font(.caption) }
                Spacer()
                Button("取消") { addTask?.cancel(); dismiss() }.keyboardShortcut(.cancelAction)
                Button("订阅", action: add)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isAdding || address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(24)
        .frame(width: 440)
        .onDisappear { addTask?.cancel() }
    }

    private func add() {
        guard !isAdding else { return }
        isAdding = true
        error = nil
        addTask = Task {
            do {
                try await store.add(title: title, address: address)
                dismiss()
            } catch is CancellationError {
            } catch {
                self.error = error.localizedDescription
            }
            isAdding = false
        }
    }
}
