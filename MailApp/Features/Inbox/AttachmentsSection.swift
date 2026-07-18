//
//  AttachmentsSection.swift
//  MailApp
//
//  Lists a message's attachments in the reading pane. Image and PDF
//  attachments auto-download and show an inline preview thumbnail (like
//  Mail.app), tappable for a full-size view; everything else stays a plain
//  download-then-share row so we're not eagerly pulling large files.
//

import SwiftUI
import PDFKit

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct AttachmentsSection: View {
    let messageId: String
    let accountEmail: String
    let attachments: [MessageAttachmentInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(attachments.count) Attachment\(attachments.count == 1 ? "" : "s")")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(attachments, id: \.attachmentId) { attachment in
                AttachmentRow(messageId: messageId, accountEmail: accountEmail, attachment: attachment)
            }
        }
    }
}

private struct AttachmentRow: View {
    let messageId: String
    let accountEmail: String
    let attachment: MessageAttachmentInfo

    @State private var isDownloading = false
    @State private var localFileURL: URL?
    @State private var previewData: Data?
    @State private var errorMessage: String?
    @State private var showingPreview = false

    private var isPreviewable: Bool {
        attachment.mimeType.hasPrefix("image/") || attachment.mimeType == "application/pdf"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .foregroundStyle(.tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.filename)
                        .font(.subheadline)
                        .lineLimit(1)
                    Text(formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isDownloading {
                    ProgressView()
                        .controlSize(.small)
                } else if let localFileURL {
                    ShareLink(item: localFileURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        Task { await download() }
                    } label: {
                        Image(systemName: "arrow.down.circle")
                    }
                    .buttonStyle(.plain)
                }
            }

            if isPreviewable, let previewData {
                previewThumbnail(data: previewData)
                    .contentShape(Rectangle())
                    .onTapGesture { showingPreview = true }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        .task {
            if isPreviewable {
                await download()
            }
        }
        .sheet(isPresented: $showingPreview) {
            if let previewData {
                AttachmentPreviewView(
                    filename: attachment.filename,
                    mimeType: attachment.mimeType,
                    data: previewData,
                    fileURL: localFileURL
                )
            }
        }
        .alert(
            "Couldn't Download Attachment",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { isPresented in if !isPresented { errorMessage = nil } }
            )
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func previewThumbnail(data: Data) -> some View {
        if attachment.mimeType.hasPrefix("image/") {
            #if os(iOS)
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            #elseif os(macOS)
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            #endif
        } else if attachment.mimeType == "application/pdf", let document = PDFDocument(data: data) {
            PDFKitPreview(document: document, isInteractive: false)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var iconName: String {
        if attachment.mimeType.hasPrefix("image/") { return "photo" }
        if attachment.mimeType.hasPrefix("video/") { return "film" }
        if attachment.mimeType == "application/pdf" { return "doc.richtext" }
        return "doc"
    }

    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(attachment.size), countStyle: .file)
    }

    private func download() async {
        guard localFileURL == nil, previewData == nil, !isDownloading else { return }
        isDownloading = true
        defer { isDownloading = false }
        do {
            guard let token = try? await AccountsManager.shared.accessToken(forAccountEmail: accountEmail) else {
                errorMessage = "Couldn't refresh access for this account."
                return
            }
            let data = try await MailSyncEngine.shared.downloadAttachment(
                messageId: messageId,
                attachmentId: attachment.attachmentId,
                accessToken: token
            )
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(attachment.filename)
            try data.write(to: url, options: .atomic)
            localFileURL = url
            previewData = data
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Full-size preview sheet for an already-downloaded image or PDF, with a share button.
private struct AttachmentPreviewView: View {
    let filename: String
    let mimeType: String
    let data: Data
    let fileURL: URL?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if mimeType.hasPrefix("image/") {
                    ScrollView([.horizontal, .vertical]) {
                        imageView
                    }
                } else if mimeType == "application/pdf", let document = PDFDocument(data: data) {
                    PDFKitPreview(document: document, isInteractive: true)
                } else {
                    ContentUnavailableView("No Preview Available", systemImage: "doc")
                }
            }
            .navigationTitle(filename)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if let fileURL {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: fileURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var imageView: some View {
        #if os(iOS)
        if let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage).resizable().scaledToFit()
        }
        #elseif os(macOS)
        if let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage).resizable().scaledToFit()
        }
        #endif
    }
}

// MARK: - PDFKit wrapper

#if os(iOS)
private struct PDFKitPreview: UIViewRepresentable {
    let document: PDFDocument
    let isInteractive: Bool

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.isUserInteractionEnabled = isInteractive
        view.document = document
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}
#elseif os(macOS)
private struct PDFKitPreview: NSViewRepresentable {
    let document: PDFDocument
    let isInteractive: Bool

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = document
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = document
    }
}
#endif
