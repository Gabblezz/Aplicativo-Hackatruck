import SwiftUI

import Foundation

import Combine

enum APIConfig {
    
    static let baseURL = "http://192.168.128.155:1880"
    
    static let documentosPath = "/api/documentos"
    
    static let usarDadosLocais = false
    
}

struct Notificacoes: Codable {
    
    var receberGeral: Bool
    
    var receberCursos: Bool
    
}

struct Usuario: Codable, Identifiable {
    
    var id: String?
    
    var rev: String?
    
    let tipo: String
    
    var nome: String
    
    var perfil: String
    
    var curso: String
    
    var notificacoes: Notificacoes
    
    enum CodingKeys: String, CodingKey {
        
        case id = "_id"
        
        case rev = "_rev"
        
        case tipo, nome, perfil, curso, notificacoes
    }
}

struct PostagemMural: Codable, Identifiable {
    
    var id: String?
    
    var rev: String?
    
    let tipo: String
    
    var authorId: String?
    
    var authorName: String
    
    var authorRole: String
    
    var authorCourse: String
    
    var text: String
    
    var timestamp: String
    
    var destino: String?
    
    var cursoDestino: String?
    
    enum CodingKeys: String, CodingKey {
        
        case id = "_id"
        
        case rev = "_rev"
        
        case tipo, authorId, authorName, authorRole, authorCourse, text, timestamp
        
        case destino, cursoDestino
        
    }
    
    var identificador: String { id ?? UUID().uuidString }
    
}

struct Anuncio: Codable, Identifiable {
    
    var id: String?
    var rev: String?
    let tipo: String
    var anuncioType: String
    var title: String
    var description: String
    
    var course: String
    
    var sellerId: String?
    
    var createdAt: String
    
    var destino: String?
    
    var cursoDestino: String?
    
    enum CodingKeys: String, CodingKey {
        
        case id = "_id"
        
        case rev = "_rev"
        
        case tipo, anuncioType, title, description, course, sellerId, createdAt
        
        case destino, cursoDestino
        
    }
    
    var identificador: String { id ?? UUID().uuidString }
    
}

struct Aviso: Codable, Identifiable {
    
    let id: String
    
    let tipo: String
    
    let usuarioId: String?
    
    let postagemId: String?
    
    let destino: String?
    
    let titulo: String
    
    let mensagem: String
    
    let curso: String?
    
    let criadaEm: String
    
    var lida: Bool
    
    enum CodingKeys: String, CodingKey {
        
        case id = "_id"
        
        case tipo, usuarioId, postagemId, destino, titulo, mensagem, curso
        
        case criadaEm, lida
        
    }
    
}

struct ListaDocumentos: Codable {
    
    let documentos: [Documento]
    
}

private struct TipoDocumento: Codable {
    
    let tipo: String
    
}

enum Documento: Codable {
    
    case usuario(Usuario)
    
    case postagem(PostagemMural)
    
    case anuncio(Anuncio)
    
    init(from decoder: Decoder) throws {
        
        let container = try decoder.singleValueContainer()
        
        let tipo = try container.decode(TipoDocumento.self).tipo
        
        switch tipo {
            
        case "usuario": self = .usuario(try container.decode(Usuario.self))
            
        case "postagem": self = .postagem(try container.decode(PostagemMural.self))
            
        case "anuncio": self = .anuncio(try container.decode(Anuncio.self))
            
        default:
            
            throw DecodingError.dataCorruptedError(
                
                in: container,
                
                debugDescription: "Tipo de documento invalido: \(tipo)"
                
            )
            
        }
        
    }
    
    
    
    func encode(to encoder: Encoder) throws {
        
        var container = encoder.singleValueContainer()
        
        switch self {
            
        case .usuario(let valor): try container.encode(valor)
            
        case .postagem(let valor): try container.encode(valor)
            
        case .anuncio(let valor): try container.encode(valor)
            
        }
        
    }
    
}

enum APIError: LocalizedError {
    
    case servidor
    
    case formatoInvalido
    
    case usuarioNaoEncontrado
    
    var errorDescription: String? {
        
        switch self {
            
        case .servidor: return "Nao foi possivel comunicar com a API."
            
        case .formatoInvalido: return "A resposta da API esta em formato invalido."
            
        case .usuarioNaoEncontrado: return "Usuario nao encontrado."
            
        }
        
    }
    
}

@MainActor

final class APIService: ObservableObject {
    
    static let shared = APIService()
    
    private let decoder = JSONDecoder()
    
    private let encoder = JSONEncoder()
    
    private var documentosURL: URL {
        
        URL(string: APIConfig.baseURL + APIConfig.documentosPath)!
        
    }
    
    func buscarDocumentos() async throws -> [Documento] {
        
        let (data, response) = try await URLSession.shared.data(from: documentosURL)
        
        try validar(response, data: data)
        
        
        
        if let documentos = try? decoder.decode([Documento].self, from: data) {
            
            return documentos
            
        }
        
        if let lista = try? decoder.decode(ListaDocumentos.self, from: data) {
            
            return lista.documentos
            
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            for chave in ["rows", "docs", "documentos"] {
                
                if let array = json[chave] as? [[String: Any]] {
                    
                    var resultado: [Documento] = []
                    
                    for item in array {
                        
                        let alvo = (item["doc"] as? [String: Any]) ?? item
                        
                        if let sub = try? JSONSerialization.data(withJSONObject: alvo),
                           
                            let doc = try? decoder.decode(Documento.self, from: sub) {
                            
                            resultado.append(doc)
                            
                        }
                        
                    }
                    
                    if !resultado.isEmpty { return resultado }
                    
                }
                
            }
            
        }
        
        throw APIError.formatoInvalido
        
    }
    
    @discardableResult
    
    func criar<T: Encodable>(_ documento: T) async throws -> String? {
        
        var request = URLRequest(url: documentosURL)
        
        request.httpMethod = "POST"
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try encoder.encode(documento)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        try validar(response, data: data)
        
        
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           
            let id = json["id"] as? String {
            
            return id
            
        }
        
        return nil
        
    }
    
    
    
    @discardableResult
    
    func atualizar<T: Encodable>(_ documento: T) async throws -> String? {
        
        var request = URLRequest(url: documentosURL)
        
        request.httpMethod = "PUT"
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try encoder.encode(documento)
        
        
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        try validar(response, data: data)
        
        
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           
            let id = json["id"] as? String {
            
            return id
            
        }
        
        return nil
        
    }
    
    
    
    func excluir(id: String, rev: String) async throws {
        
        var request = URLRequest(url: documentosURL)
        
        request.httpMethod = "DELETE"
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try encoder.encode(["_id": id, "_rev": rev])
        
        
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        try validar(response, data: data)
        
    }
    
    
    
    func buscarUsuario(id: String) async throws -> Usuario {
        
        guard let url = URL(string: APIConfig.baseURL + "/api/usuarios/\(id)") else {
            
            throw APIError.servidor
            
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        try validar(response, data: data)
        
        return try decoder.decode(Usuario.self, from: data)
        
    }
    
    
    
    func buscarAvisos(usuarioId: String) async throws -> [Aviso] {
        
        guard let url = URL(string: APIConfig.baseURL + "/api/notificacoes/\(usuarioId)") else {
            
            throw APIError.servidor
            
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        try validar(response, data: data)
        
        return try decoder.decode([Aviso].self, from: data)
        
    }
    
    func atualizarPreferencias(
        
        usuarioId: String,
        
        receberGeral: Bool,
        
        receberCursos: Bool
        
    ) async throws {
        
        guard let url = URL(string: APIConfig.baseURL + "/api/usuarios/\(usuarioId)/notificacoes") else {
            
            throw APIError.servidor
            
        }
        
        var request = URLRequest(url: url)
        
        request.httpMethod = "PUT"
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try encoder.encode(
            
            Notificacoes(receberGeral: receberGeral, receberCursos: receberCursos)
            
        )
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        try validar(response, data: data)
        
    }
    
    
    
    private func validar(_ response: URLResponse, data: Data) throws {
        
        guard let http = response as? HTTPURLResponse else {
            
            throw APIError.servidor
            
        }
        
        guard 200..<300 ~= http.statusCode else {
            
            print("HTTP \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            
            throw APIError.servidor
            
        }
        
    }
    
}



struct ContentView: View {
    
    @AppStorage("userRole") private var userRole = ""
    
    @AppStorage("isProfileCompleted") private var isProfileCompleted = false
    
    @AppStorage("userId") private var userId = ""
    
    @AppStorage("userName") private var userName = ""
    
    @AppStorage("userCourse") private var userCourse = ""
    
    @AppStorage("receberGeral") private var receberGeral = true
    
    @AppStorage("receberCursos") private var receberCursos = true
    
    
    
    var body: some View {
        
        Group {
            
            if userRole.isEmpty {
                
                RoleSelectionView(userRole: $userRole)
                
            } else if !isProfileCompleted {
                
                CompleteInfoView(
                    
                    userRole: $userRole,
                    
                    isProfileCompleted: $isProfileCompleted,
                    
                    userId: $userId,
                    
                    userName: $userName,
                    
                    userCourse: $userCourse,
                    
                    receberGeral: $receberGeral,
                    
                    receberCursos: $receberCursos
                    
                )
                
            } else {
                
                MainDashboardView(
                    
                    userRole: $userRole,
                    
                    isProfileCompleted: $isProfileCompleted,
                    
                    userId: $userId,
                    
                    userName: $userName,
                    
                    userCourse: $userCourse,
                    
                    receberGeral: $receberGeral,
                    
                    receberCursos: $receberCursos
                    
                )
                
            }
            
        }
        
    }
    
}



struct RoleSelectionView: View {
    
    @Binding var userRole: String
    @State private var isAnimating = false
    
    var body: some View {
        
        NavigationStack {
            ZStack{
                MeshGradient(
                    width: 4,
                    height: 4,
                    points: [
                        // Top row
                        [0.0, 0.0], [0.3, 0.0], [0.6,0.0], [1.0, 0.0],
                        // Middle row (Animating X and Y to create fluid shift)
                        [-0.1, 0.5], [isAnimating ? 0.5 : 0.6, isAnimating ? 0.3 : 0.6], [1.1, 0.5], [isAnimating ? 0.9 : 0.7, isAnimating ? 0.3 : 0.6],
                        
                        [0.0,0.7],[isAnimating ? 0.3 : 0.5, isAnimating ? 0.4: 0.8],[isAnimating ? 0.51 : 0.61, isAnimating ? 0.7 : 0.75],[1.0, 0.6],
                        // Bottom row
                        [0.0, 1.0], [isAnimating ? 0.5 : 0.7, 1.0], [isAnimating ? 0.7 : 1.0, 1.0]
                    ],
                    colors: [
                        .white, .indigo, .blue, .purple,
                        .teal, .purple, .cyan, .blue,
                        .blue, .teal, .purple, .pink,
                        .clear, .blue, .cyan, .indigo
                    ]
                )
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                        isAnimating.toggle()
                    }
                }
                
                VStack(spacing: 24) {
                    
                    Image(systemName: "building.columns.fill")
                    
                        .font(.system(size: 54))
                    
                        .foregroundStyle(.blue)
                    
                    Text("Portal Universitario")
                    
                        .font(.largeTitle.bold())
                    
                        .multilineTextAlignment(.center)
                    
                    
                    
                    Text("Selecione como voce utiliza o aplicativo")
                    
                        .foregroundStyle(.secondary)
                    
                        .multilineTextAlignment(.center)
                    
                    roleButton("Sou Aluno", role: "aluno", color: .blue, icon: "graduationcap.fill")
                    
                    roleButton("Sou Professor", role: "professor", color: .pink, icon: "person.fill")
                    
                    roleButton("Sou Agente Universitario", role: "agente", color: .red, icon: "building.2.fill")
                    
                }
                
                .padding(24)
                
                .navigationTitle("Bem-vindo")
            }
            
        }
        
    }
    
    
    
    private func roleButton(_ title: String, role: String, color: Color, icon: String) -> some View {
        
        Button {
            
            userRole = role
            
        } label: {
            
            Label(title, systemImage: icon)
            
                .font(.headline)
            
                .foregroundStyle(.white)
            
                .frame(maxWidth: .infinity)
            
                .padding()
            
                .background(color, in: RoundedRectangle(cornerRadius: 14))
            
        }
        
    }
    
}



struct CompleteInfoView: View {
    
    @Binding var userRole: String
    
    @Binding var isProfileCompleted: Bool
    
    @Binding var userId: String
    
    @Binding var userName: String
    
    @Binding var userCourse: String
    
    @Binding var receberGeral: Bool
    
    @Binding var receberCursos: Bool
    
    
    
    @State private var name = ""
    
    @State private var course = ""
    
    @State private var saving = false
    
    @State private var errorMessage = ""
    
    
    
    private let cursos = Cursos.lista
    
    
    
    var body: some View {
        
        NavigationStack {
            
            Form {
                
                Section("Dados pessoais") {
                    
                    TextField("Nome completo", text: $name)
                    
                    Picker("Curso / setor", selection: $course) {
                        
                        Text("Selecione uma opcao").tag("")
                        
                        ForEach(cursos, id: \.self) { Text($0).tag($0) }
                        
                    }
                    
                }
                
                
                
                Section("Preferencias de notificacao") {
                    
                    Toggle("Receber avisos de @geral", isOn: $receberGeral)
                    
                    Toggle("Receber avisos do meu curso", isOn: $receberCursos)
                    
                }
                
                
                
                Button {
                    
                    Task { await salvar() }
                    
                } label: {
                    
                    HStack {
                        
                        Spacer()
                        
                        if saving { ProgressView().tint(.white) }
                        
                        else { Text("Concluir cadastro").bold() }
                        
                        Spacer()
                        
                    }
                    
                }
                
                .foregroundStyle(.white)
                
                .listRowBackground(Color.blue)
                
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || course.isEmpty || saving)
                
            }
            
            .navigationTitle("Complete seu perfil")
            
            .alert("Erro", isPresented: Binding(get: { !errorMessage.isEmpty }, set: { if !$0 { errorMessage = "" } })) {
                
                Button("OK") { errorMessage = "" }
                
            } message: { Text(errorMessage) }
            
        }
        
    }
    
    
    
    private func salvar() async {
        
        saving = true
        
        defer { saving = false }
        
        
        
        let idLocal = UUID().uuidString
        
        let nome = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let usuario = Usuario(
            
            id: idLocal,
            
            rev: nil,
            
            tipo: "usuario",
            
            nome: nome,
            
            perfil: userRole,
            
            curso: course,
            
            notificacoes: Notificacoes(receberGeral: receberGeral, receberCursos: receberCursos)
            
        )
        
        
        
        do {
            
            var idFinal = idLocal
            
            if !APIConfig.usarDadosLocais {
                
                if let idServidor = try await APIService.shared.criar(usuario) {
                    
                    idFinal = idServidor
                    
                }
                
            }
            
            userId = idFinal
            
            userName = nome
            
            userCourse = course
            
            isProfileCompleted = true
            
        } catch {
            
            errorMessage = error.localizedDescription
            
        }
        
    }
    
}



struct MainDashboardView: View {
    
    @Binding var userRole: String
    
    @Binding var isProfileCompleted: Bool
    
    @Binding var userId: String
    
    @Binding var userName: String
    
    @Binding var userCourse: String
    
    @Binding var receberGeral: Bool
    
    @Binding var receberCursos: Bool
    
    
    
    var body: some View {
        
        TabView {
            
            MuralGeralView(
                
                userRole: userRole,
                
                userId: userId,
                
                userName: userName,
                
                userCourse: userCourse
                
            )
            
            .tabItem { Label("Mural", systemImage: "megaphone.fill") }
            
            
            
            ClassificadosView(userId: userId)
            
                .tabItem { Label("Classificados", systemImage: "cart.fill") }
            
            
            
            AreaExclusivaView(
                
                userRole: $userRole,
                
                isProfileCompleted: $isProfileCompleted,
                
                userId: $userId,
                
                userName: $userName,
                
                userCourse: $userCourse,
                
                receberGeral: $receberGeral,
                
                receberCursos: $receberCursos
                
            )
            
            .tabItem { Label("Para voce", systemImage: "person.crop.circle.fill") }
            
        }
        
    }
    
}



struct MuralGeralView: View {
    
    let userRole: String
    
    let userId: String
    
    let userName: String
    
    let userCourse: String
    
    
    
    @State private var postagens: [PostagemMural] = []
    
    @State private var showingNewPost = false
    
    @State private var loading = false
    
    @State private var errorMessage = ""
    
    
    
    var body: some View {
        
        NavigationStack {
            
            Group {
                
                if loading {
                    
                    ProgressView("Carregando mural...")
                    
                } else if postagens.isEmpty {
                    
                    EmptyStateView(icon: "megaphone", title: "Nenhuma postagem", message: "Seja o primeiro a publicar um aviso.")
                    
                } else {
                    
                    ScrollView {
                        
                        LazyVStack(spacing: 12) {
                            
                            ForEach(postagens) { postagem in
                                
                                PostCard(postagem: postagem)
                                
                            }
                            
                        }
                        
                        .padding()
                        
                    }
                    
                    .refreshable { await carregar() }
                    
                }
                
            }
            
            .navigationTitle("Mural Geral")
            
            .toolbar {
                
                ToolbarItem(placement: .topBarTrailing) {
                    
                    Button { showingNewPost = true } label: {
                        
                        Image(systemName: "plus.circle.fill")
                        
                    }
                    
                }
                
            }
            
            .sheet(isPresented: $showingNewPost) {
                
                NewPostView(
                    
                    userRole: userRole,
                    
                    userId: userId,
                    
                    userName: userName,
                    
                    userCourse: userCourse
                    
                ) {
                    
                    Task { await carregar() }
                    
                }
                
            }
            
            .task { await carregar() }
            
            .alert("Erro", isPresented: Binding(get: { !errorMessage.isEmpty }, set: { if !$0 { errorMessage = "" } })) {
                
                Button("OK") { errorMessage = "" }
                
            } message: { Text(errorMessage) }
            
        }
        
    }
    
    
    
    private func carregar() async {
        
        loading = true
        
        defer { loading = false }
        
        
        
        if APIConfig.usarDadosLocais {
            
            postagens = []
            
            return
            
        }
        
        
        
        do {
            
            postagens = try await APIService.shared.buscarDocumentos().compactMap {
                
                if case .postagem(let postagem) = $0 { return postagem }
                
                return nil
                
            }
            
            .sorted { $0.timestamp > $1.timestamp }
            
            errorMessage = ""
            
        } catch {
            
            errorMessage = error.localizedDescription
            
        }
        
    }
    
}



struct PostCard: View {
    
    let postagem: PostagemMural
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 10) {
            
            HStack {
                
                Image(systemName: "person.circle.fill")
                
                    .font(.title2)
                
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading) {
                    
                    Text(postagem.authorName).font(.headline)
                    
                    Text("\(postagem.authorRole) - \(postagem.authorCourse)")
                    
                        .font(.caption)
                    
                        .foregroundStyle(.secondary)
                    
                }
                
                Spacer()
                
                if let destino = postagem.destino {
                    
                    Text(destino == "@geral" ? "@geral" : "@\(postagem.cursoDestino ?? "")")
                    
                        .font(.caption.bold())
                    
                        .foregroundStyle(.blue)
                    
                }
                
            }
            
            Text(postagem.text)
            
        }
        
        .padding()
        
        .frame(maxWidth: .infinity, alignment: .leading)
        
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        
    }
    
}



struct NewPostView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    let userRole: String
    
    let userId: String
    
    let userName: String
    
    let userCourse: String
    
    let onSaved: () -> Void
    
    
    
    @State private var destino = "@geral"
    
    @State private var cursoEscolhido = ""
    
    @State private var texto = ""
    
    @State private var saving = false
    
    @State private var errorMessage = ""
    
    
    
    private let cursos = Cursos.lista
    
    
    
    var body: some View {
        
        NavigationStack {
            
            Form {
                
                Section("Destino") {
                    
                    Picker("Notificar", selection: $destino) {
                        
                        Text("Todos (@geral)").tag("@geral")
                        
                        Text("Curso especifico (@curso)").tag("@curso")
                        
                    }
                    
                    .pickerStyle(.segmented)
                    
                    
                    
                    if destino == "@curso" {
                        
                        Picker("Escolha o curso", selection: $cursoEscolhido) {
                            
                            Text("Selecione um curso").tag("")
                            
                            ForEach(cursos, id: \.self) { Text($0).tag($0) }
                            
                        }
                        
                    }
                    
                }
                
                
                
                Section("Mensagem") {
                    
                    TextEditor(text: $texto)
                    
                        .frame(minHeight: 140)
                    
                }
                
                
                
                Button {
                    
                    Task { await publicar() }
                    
                } label: {
                    
                    HStack {
                        
                        Spacer()
                        
                        if saving { ProgressView() } else { Text("Publicar").bold() }
                        
                        Spacer()
                        
                    }
                    
                }
                
                .disabled(!podeSalvar || saving)
                
            }
            
            .navigationTitle("Nova postagem")
            
            .toolbar {
                
                ToolbarItem(placement: .cancellationAction) {
                    
                    Button("Cancelar") { dismiss() }
                    
                }
                
            }
            
            .alert("Erro", isPresented: Binding(get: { !errorMessage.isEmpty }, set: { if !$0 { errorMessage = "" } })) {
                
                Button("OK") { errorMessage = "" }
                
            } message: { Text(errorMessage) }
            
        }
        
    }
    
    
    
    private var podeSalvar: Bool {
        
        if texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        
        if destino == "@curso" && cursoEscolhido.isEmpty { return false }
        
        return true
        
    }
    
    
    
    private func publicar() async {
        
        saving = true
        
        defer { saving = false }
        
        
        
        let cursoFinal: String? = destino == "@geral" ? nil : cursoEscolhido
        
        let mencao = destino == "@geral" ? "@geral" : "@\(cursoEscolhido)"
        
        
        
        let postagem = PostagemMural(
            
            id: nil,
            
            rev: nil,
            
            tipo: "postagem",
            
            authorId: userId.isEmpty ? nil : userId,
            
            authorName: userName,
            
            authorRole: userRole.capitalized,
            
            authorCourse: userCourse,
            
            text: "\(mencao) \(texto.trimmingCharacters(in: .whitespacesAndNewlines))",
            
            timestamp: ISO8601DateFormatter().string(from: Date()),
            
            destino: destino,
            
            cursoDestino: cursoFinal
            
        )
        
        
        
        do {
            
            try await APIService.shared.criar(postagem)
            
            onSaved()
            
            dismiss()
            
        } catch {
            
            errorMessage = error.localizedDescription
            
        }
        
    }
    
}



struct ClassificadosView: View {
    
    let userId: String
    
    
    
    @State private var anuncios: [Anuncio] = []
    
    @State private var showingNew = false
    
    @State private var search = ""
    
    @State private var errorMessage = ""
    
    
    
    private var filtrados: [Anuncio] {
        
        guard !search.isEmpty else { return anuncios }
        
        return anuncios.filter {
            
            $0.title.localizedCaseInsensitiveContains(search) ||
            
            $0.description.localizedCaseInsensitiveContains(search)
            
        }
        
    }
    
    
    
    var body: some View {
        
        NavigationStack {
            
            Group {
                
                if filtrados.isEmpty {
                    
                    EmptyStateView(icon: "cart", title: "Nenhum anuncio", message: "Publique materiais, quartos ou servicos.")
                    
                } else {
                    
                    List(filtrados) { anuncio in
                        
                        AnuncioRow(anuncio: anuncio)
                        
                    }
                    
                    .listStyle(.plain)
                    
                    .refreshable { await carregar() }
                    
                }
                
            }
            
            .navigationTitle("Classificados")
            
            .searchable(text: $search, prompt: "Buscar anuncio")
            
            .toolbar {
                
                ToolbarItem(placement: .topBarTrailing) {
                    
                    Button { showingNew = true } label: {
                        
                        Image(systemName: "plus.circle.fill")
                        
                    }
                    
                }
                
            }
            
            .sheet(isPresented: $showingNew) {
                
                NewAnuncioView(userId: userId) { Task { await carregar() } }
                
            }
            
            .task { await carregar() }
            
            .alert("Erro", isPresented: Binding(get: { !errorMessage.isEmpty }, set: { if !$0 { errorMessage = "" } })) {
                
                Button("OK") { errorMessage = "" }
                
            } message: { Text(errorMessage) }
            
        }
        
    }
    
    
    
    private func carregar() async {
        
        do {
            
            anuncios = try await APIService.shared.buscarDocumentos().compactMap {
                
                if case .anuncio(let anuncio) = $0 { return anuncio }
                
                return nil
                
            }
            
            errorMessage = ""
            
        } catch {
            
            errorMessage = error.localizedDescription
            
        }
        
    }
    
}



struct AnuncioRow: View {
    
    let anuncio: Anuncio
    
    
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 7) {
            
            HStack {
                
                Text(anuncio.anuncioType.uppercased())
                
                    .font(.caption.bold())
                
                    .foregroundStyle(.blue)
                
                Spacer()
                
                if let destino = anuncio.destino {
                    
                    Text(destino == "@geral" ? "@geral" : "@\(anuncio.cursoDestino ?? "")")
                    
                        .font(.caption.bold())
                    
                        .foregroundStyle(.blue)
                    
                }
                
            }
            
            Text(anuncio.title).font(.headline)
            
            Text(anuncio.description).foregroundStyle(.secondary)
            
        }
        
        .padding(.vertical, 8)
        
    }
    
}



struct NewAnuncioView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    let userId: String
    
    let onSaved: () -> Void
    
    
    
    @State private var type = "Material"
    
    @State private var title = ""
    
    @State private var description = ""
    
    @State private var destino = "@geral"
    
    @State private var cursoEscolhido = ""
    
    @State private var saving = false
    
    @State private var errorMessage = ""
    
    
    
    private let categorias = ["Material", "Residencia", "Servico", "Outro"]
    
    private let cursos = Cursos.lista
    
    
    
    var body: some View {
        
        NavigationStack {
            
            Form {
                
                Picker("Categoria", selection: $type) {
                    
                    ForEach(categorias, id: \.self) { Text($0) }
                    
                }
                
                
                
                Section("Destino do anuncio") {
                    
                    Picker("Notificar", selection: $destino) {
                        
                        Text("Todos (@geral)").tag("@geral")
                        
                        Text("Curso especifico (@curso)").tag("@curso")
                        
                    }
                    
                    .pickerStyle(.segmented)
                    
                    
                    
                    if destino == "@curso" {
                        
                        Picker("Escolha o curso", selection: $cursoEscolhido) {
                            
                            Text("Selecione um curso").tag("")
                            
                            ForEach(cursos, id: \.self) { Text($0).tag($0) }
                            
                        }
                        
                    }
                    
                }
                
                
                
                Section("Detalhes") {
                    
                    TextField("Titulo", text: $title)
                    
                    TextEditor(text: $description)
                    
                        .frame(minHeight: 120)
                    
                }
                
                
                
                Button {
                    
                    Task { await salvar() }
                    
                } label: {
                    
                    HStack {
                        
                        Spacer()
                        
                        if saving { ProgressView() } else { Text("Publicar anuncio").bold() }
                        
                        Spacer()
                        
                    }
                    
                }
                
                .disabled(!podeSalvar || saving)
                
            }
            
            .navigationTitle("Novo anuncio")
            
            .toolbar {
                
                ToolbarItem(placement: .cancellationAction) {
                    
                    Button("Cancelar") { dismiss() }
                    
                }
                
            }
            
            .alert("Erro", isPresented: Binding(get: { !errorMessage.isEmpty }, set: { if !$0 { errorMessage = "" } })) {
                
                Button("OK") { errorMessage = "" }
                
            } message: { Text(errorMessage) }
            
        }
        
    }
    
    
    
    private var podeSalvar: Bool {
        
        if title.isEmpty || description.isEmpty { return false }
        
        if destino == "@curso" && cursoEscolhido.isEmpty { return false }
        
        return true
        
    }
    
    
    
    private func salvar() async {
        
        saving = true
        
        defer { saving = false }
        
        
        
        let cursoFinal = destino == "@geral" ? "Geral / Todos" : cursoEscolhido
        
        
        
        let anuncio = Anuncio(
            
            id: nil,
            
            rev: nil,
            
            tipo: "anuncio",
            
            anuncioType: type,
            
            title: title,
            
            description: description,
            
            course: cursoFinal,
            
            sellerId: userId.isEmpty ? nil : userId,
            
            createdAt: ISO8601DateFormatter().string(from: Date()),
            
            destino: destino,
            
            cursoDestino: destino == "@geral" ? nil : cursoEscolhido
            
        )
        
        
        
        do {
            
            try await APIService.shared.criar(anuncio)
            
            onSaved()
            
            dismiss()
            
        } catch {
            
            errorMessage = error.localizedDescription
            
        }
        
    }
    
}



struct AreaExclusivaView: View {
    
    @Binding var userRole: String
    
    @Binding var isProfileCompleted: Bool
    
    @Binding var userId: String
    
    @Binding var userName: String
    
    @Binding var userCourse: String
    
    @Binding var receberGeral: Bool
    
    @Binding var receberCursos: Bool
    
    
    
    @State private var mostrarAvisos = false
    
    @State private var mostrarPublicacoes = false
    
    @State private var mostrarConfiguracoes = false
    
    
    
    var body: some View {
        
        NavigationStack {
            
            List {
                
                Section {
                    
                    Label {
                        
                        VStack(alignment: .leading, spacing: 4) {
                            
                            Text(userName.isEmpty ? userRole.capitalized : userName)
                            
                                .font(.title3.bold())
                            
                            Text(userCourse)
                            
                                .font(.subheadline)
                            
                                .foregroundStyle(.secondary)
                            
                        }
                        
                    } icon: {
                        
                        Image(systemName: "person.crop.circle.fill")
                        
                            .foregroundStyle(.blue)
                        
                    }
                    
                }
                
                
                
                Section("Minha conta") {
                    
                    Button { mostrarAvisos = true } label: {
                        
                        Label("Meus avisos", systemImage: "bell.badge.fill")
                        
                    }
                    
                    
                    
                    Button { mostrarPublicacoes = true } label: {
                        
                        Label("Minhas publicacoes", systemImage: "doc.text.fill")
                        
                    }
                    
                    
                    
                    Button { mostrarConfiguracoes = true } label: {
                        
                        Label("Configuracoes", systemImage: "gearshape.fill")
                        
                    }
                    
                }
                
                
                
                Section {
                    
                    Button(role: .destructive) {
                        
                        userRole = ""
                        
                        isProfileCompleted = false
                        
                        userId = ""
                        
                        userName = ""
                        
                        userCourse = ""
                        
                    } label: {
                        
                        Label("Sair e redefinir perfil", systemImage: "rectangle.portrait.and.arrow.right")
                        
                    }
                    
                }
                
            }
            
            .navigationTitle("Para Voce")
            
            .sheet(isPresented: $mostrarAvisos) {
                
                MeusAvisosView(usuarioId: userId)
                
            }
            
            .sheet(isPresented: $mostrarPublicacoes) {
                
                MinhasPublicacoesView(
                    
                    userId: userId,
                    
                    userName: userName,
                    
                    userCourse: userCourse
                    
                )
                
            }
            
            .sheet(isPresented: $mostrarConfiguracoes) {
                
                ConfiguracoesView(
                    
                    usuarioId: userId,
                    
                    receberGeral: $receberGeral,
                    
                    receberCursos: $receberCursos
                    
                )
                
            }
            
        }
        
    }
    
}



struct MeusAvisosView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    let usuarioId: String
    
    
    
    @State private var avisos: [Aviso] = []
    
    @State private var loading = false
    
    @State private var errorMessage = ""
    
    
    
    var body: some View {
        
        NavigationStack {
            
            Group {
                
                if loading {
                    
                    ProgressView("Carregando avisos...")
                    
                } else if avisos.isEmpty {
                    
                    EmptyStateView(icon: "bell", title: "Nenhum aviso", message: "Voce ainda nao recebeu avisos.")
                    
                } else {
                    
                    List(avisos) { aviso in
                        
                        VStack(alignment: .leading, spacing: 8) {
                            
                            HStack {
                                
                                Image(systemName: aviso.destino == "@geral" ? "globe" : "graduationcap.fill")
                                
                                    .foregroundStyle(.blue)
                                
                                Text(aviso.titulo).font(.headline)
                                
                                Spacer()
                                
                                if !aviso.lida {
                                    
                                    Circle().fill(.blue).frame(width: 9, height: 9)
                                    
                                }
                                
                            }
                            
                            Text(aviso.mensagem)
                            
                            Text(aviso.destino == "@geral" ? "@geral" : "@\(aviso.curso ?? "")")
                            
                                .font(.caption)
                            
                                .foregroundStyle(.secondary)
                            
                        }
                        
                        .padding(.vertical, 6)
                        
                    }
                    
                }
                
            }
            
            .navigationTitle("Meus avisos")
            
            .toolbar {
                
                ToolbarItem(placement: .cancellationAction) {
                    
                    Button("Fechar") { dismiss() }
                    
                }
                
            }
            
            .task { await carregar() }
            
            .refreshable { await carregar() }
            
            .alert("Erro", isPresented: Binding(get: { !errorMessage.isEmpty }, set: { if !$0 { errorMessage = "" } })) {
                
                Button("OK") { errorMessage = "" }
                
            } message: { Text(errorMessage) }
            
        }
        
    }
    
    
    
    private func carregar() async {
        
        guard !usuarioId.isEmpty else { return }
        
        loading = true
        
        defer { loading = false }
        
        do {
            
            avisos = try await APIService.shared.buscarAvisos(usuarioId: usuarioId)
            
            errorMessage = ""
            
        } catch {
            
            errorMessage = error.localizedDescription
            
        }
        
    }
    
}



struct MinhasPublicacoesView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    let userId: String
    
    let userName: String
    
    let userCourse: String
    
    
    
    @State private var postagensMural: [PostagemMural] = []
    
    @State private var anuncios: [Anuncio] = []
    
    @State private var loading = false
    
    @State private var errorMessage = ""
    
    @State private var abaSelecionada = 0
    
    
    
    @State private var editandoPostagem: PostagemMural?
    
    @State private var editandoAnuncio: Anuncio?
    
    @State private var confirmarExclusaoPostagem: PostagemMural?
    
    @State private var confirmarExclusaoAnuncio: Anuncio?
    
    
    
    var body: some View {
        
        NavigationStack {
            
            Group {
                
                if loading {
                    
                    ProgressView("Carregando publicacoes...")
                    
                } else {
                    
                    VStack(spacing: 0) {
                        
                        Picker("Categoria", selection: $abaSelecionada) {
                            
                            Text("Mural (\(postagensMural.count))").tag(0)
                            
                            Text("Classificados (\(anuncios.count))").tag(1)
                            
                        }
                        
                        .pickerStyle(.segmented)
                        
                        .padding()
                        
                        
                        
                        if abaSelecionada == 0 {
                            
                            if postagensMural.isEmpty {
                                
                                EmptyStateView(
                                    
                                    icon: "megaphone",
                                    
                                    title: "Nenhuma postagem no mural",
                                    
                                    message: "Suas postagens do mural aparecerao aqui."
                                    
                                )
                                
                            } else {
                                
                                List {
                                    
                                    ForEach(postagensMural) { postagem in
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            
                                            HStack {
                                                
                                                Text(postagem.destino == "@geral" ? "@geral" : "@\(postagem.cursoDestino ?? "")")
                                                
                                                    .font(.caption.bold())
                                                
                                                    .foregroundStyle(.blue)
                                                
                                                Spacer()
                                                
                                                Text(formatarData(postagem.timestamp))
                                                
                                                    .font(.caption)
                                                
                                                    .foregroundStyle(.secondary)
                                                
                                            }
                                            
                                            Text(postagem.text)
                                            
                                                .font(.body)
                                            
                                            HStack {
                                                
                                                Button {
                                                    
                                                    editandoPostagem = postagem
                                                    
                                                } label: {
                                                    
                                                    Label("Editar", systemImage: "pencil")
                                                    
                                                        .font(.caption)
                                                    
                                                }
                                                
                                                .buttonStyle(.bordered)
                                                
                                                
                                                
                                                Button(role: .destructive) {
                                                    
                                                    confirmarExclusaoPostagem = postagem
                                                    
                                                } label: {
                                                    
                                                    Label("Excluir", systemImage: "trash")
                                                    
                                                        .font(.caption)
                                                    
                                                }
                                                
                                                .buttonStyle(.bordered)
                                                
                                            }
                                            
                                        }
                                        
                                        .padding(.vertical, 6)
                                        
                                    }
                                    
                                }
                                
                                .listStyle(.plain)
                                
                            }
                            
                        } else {
                            
                            if anuncios.isEmpty {
                                
                                EmptyStateView(
                                    
                                    icon: "cart",
                                    
                                    title: "Nenhum anuncio",
                                    
                                    message: "Seus anuncios dos classificados aparecerao aqui."
                                    
                                )
                                
                            } else {
                                
                                List {
                                    
                                    ForEach(anuncios) { anuncio in
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            
                                            HStack {
                                                
                                                Text(anuncio.anuncioType.uppercased())
                                                
                                                    .font(.caption.bold())
                                                
                                                    .foregroundStyle(.blue)
                                                
                                                Spacer()
                                                
                                                Text(anuncio.destino == "@geral" ? "@geral" : "@\(anuncio.cursoDestino ?? "")")
                                                
                                                    .font(.caption)
                                                
                                                    .foregroundStyle(.secondary)
                                                
                                            }
                                            
                                            Text(anuncio.title).font(.headline)
                                            
                                            Text(anuncio.description)
                                            
                                                .foregroundStyle(.secondary)
                                            
                                            HStack {
                                                
                                                Button {
                                                    
                                                    editandoAnuncio = anuncio
                                                    
                                                } label: {
                                                    
                                                    Label("Editar", systemImage: "pencil")
                                                    
                                                        .font(.caption)
                                                    
                                                }
                                                
                                                .buttonStyle(.bordered)
                                                
                                                
                                                
                                                Button(role: .destructive) {
                                                    
                                                    confirmarExclusaoAnuncio = anuncio
                                                    
                                                } label: {
                                                    
                                                    Label("Excluir", systemImage: "trash")
                                                    
                                                        .font(.caption)
                                                    
                                                }
                                                
                                                .buttonStyle(.bordered)
                                                
                                            }
                                            
                                        }
                                        
                                        .padding(.vertical, 6)
                                        
                                    }
                                    
                                }
                                
                                .listStyle(.plain)
                                
                            }
                            
                        }
                        
                    }
                    
                }
                
            }
            
            .navigationTitle("Minhas publicacoes")
            
            .toolbar {
                
                ToolbarItem(placement: .cancellationAction) {
                    
                    Button("Fechar") { dismiss() }
                    
                }
                
            }
            
            .task { await carregar() }
            
            .refreshable { await carregar() }
            
            .alert("Erro", isPresented: Binding(get: { !errorMessage.isEmpty }, set: { if !$0 { errorMessage = "" } })) {
                
                Button("OK") { errorMessage = "" }
                
            } message: { Text(errorMessage) }
            
            
            
                .sheet(item: $editandoPostagem) { postagem in
                    
                    EditarPostagemView(postagem: postagem) {
                        
                        Task { await carregar() }
                        
                    }
                    
                }
            
                .sheet(item: $editandoAnuncio) { anuncio in
                    
                    EditarAnuncioView(anuncio: anuncio) {
                        
                        Task { await carregar() }
                        
                    }
                    
                }
            
            
            
                .alert("Excluir postagem do mural", isPresented: Binding(
                    
                    get: { confirmarExclusaoPostagem != nil },
                    
                    set: { if !$0 { confirmarExclusaoPostagem = nil } }
                    
                )) {
                    
                    Button("Cancelar", role: .cancel) { confirmarExclusaoPostagem = nil }
                    
                    Button("Excluir", role: .destructive) {
                        
                        if let p = confirmarExclusaoPostagem {
                            
                            Task { await excluirPostagem(p) }
                            
                        }
                        
                    }
                    
                } message: {
                    
                    Text("Tem certeza que deseja excluir esta postagem?")
                    
                }
            
                .alert("Excluir anuncio", isPresented: Binding(
                    
                    get: { confirmarExclusaoAnuncio != nil },
                    
                    set: { if !$0 { confirmarExclusaoAnuncio = nil } }
                    
                )) {
                    
                    Button("Cancelar", role: .cancel) { confirmarExclusaoAnuncio = nil }
                    
                    Button("Excluir", role: .destructive) {
                        
                        if let a = confirmarExclusaoAnuncio {
                            
                            Task { await excluirAnuncio(a) }
                            
                        }
                        
                    }
                    
                } message: {
                    
                    Text("Tem certeza que deseja excluir este anuncio?")
                    
                }
            
        }
        
    }
    
    
    
    private func carregar() async {
        
        guard !userId.isEmpty else {
            
            errorMessage = "Usuario nao identificado."
            
            return
            
        }
        
        loading = true
        
        defer { loading = false }
        
        
        
        do {
            
            let documentos = try await APIService.shared.buscarDocumentos()
            
            
            
            postagensMural = documentos.compactMap {
                
                guard case .postagem(let p) = $0 else { return nil }
                
                if let autorId = p.authorId, !autorId.isEmpty {
                    
                    return autorId == userId ? p : nil
                    
                }
                
                let mesmoNome = p.authorName.caseInsensitiveCompare(userName) == .orderedSame
                
                let mesmoCurso = p.authorCourse.caseInsensitiveCompare(userCourse) == .orderedSame
                
                return mesmoNome && mesmoCurso ? p : nil
                
            }
            
            .sorted { $0.timestamp > $1.timestamp }
            
            
            
            anuncios = documentos.compactMap {
                
                guard case .anuncio(let a) = $0 else { return nil }
                
                guard let sellerId = a.sellerId, !sellerId.isEmpty else { return nil }
                
                return sellerId == userId ? a : nil
                
            }
            
            .sorted { $0.createdAt > $1.createdAt }
            
            
            
            errorMessage = ""
            
        } catch {
            
            errorMessage = error.localizedDescription
            
        }
        
    }
    
    
    
    private func excluirPostagem(_ postagem: PostagemMural) async {
        
        guard let id = postagem.id, let rev = postagem.rev else {
            
            errorMessage = "Postagem sem id/revisao."
            
            confirmarExclusaoPostagem = nil
            
            return
            
        }
        
        do {
            
            try await APIService.shared.excluir(id: id, rev: rev)
            
            await carregar()
            
        } catch {
            
            errorMessage = error.localizedDescription
            
        }
        
        confirmarExclusaoPostagem = nil
        
    }
    
    
    
    private func excluirAnuncio(_ anuncio: Anuncio) async {
        
        guard let id = anuncio.id, let rev = anuncio.rev else {
            
            errorMessage = "Anuncio sem id/revisao."
            
            confirmarExclusaoAnuncio = nil
            
            return
            
        }
        
        do {
            
            try await APIService.shared.excluir(id: id, rev: rev)
            
            await carregar()
            
        } catch {
            
            errorMessage = error.localizedDescription
            
        }
        
        confirmarExclusaoAnuncio = nil
        
    }
    
    
    
    private func formatarData(_ iso: String) -> String {
        
        let isoFormatter = ISO8601DateFormatter()
        
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var data = isoFormatter.date(from: iso)
        
        if data == nil {
            
            isoFormatter.formatOptions = [.withInternetDateTime]
            
            data = isoFormatter.date(from: iso)
            
        }
        
        guard let d = data else { return iso }
        
        let f = DateFormatter()
        
        f.dateFormat = "dd/MM/yyyy HH:mm"
        
        return f.string(from: d)
        
    }
    
}



struct EditarPostagemView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    let postagem: PostagemMural
    
    let onSaved: () -> Void
    
    
    
    @State private var texto = ""
    
    @State private var destino = "@geral"
    
    @State private var cursoEscolhido = ""
    
    @State private var saving = false
    
    @State private var errorMessage = ""
    
    
    
    private let cursos = Cursos.lista
    
    
    
    var body: some View {
        
        NavigationStack {
            
            Form {
                
                Section("Destino") {
                    
                    Picker("Notificar", selection: $destino) {
                        
                        Text("Todos (@geral)").tag("@geral")
                        
                        Text("Curso especifico (@curso)").tag("@curso")
                        
                    }
                    
                    .pickerStyle(.segmented)
                    
                    
                    
                    if destino == "@curso" {
                        
                        Picker("Escolha o curso", selection: $cursoEscolhido) {
                            
                            Text("Selecione um curso").tag("")
                            
                            ForEach(cursos, id: \.self) { Text($0).tag($0) }
                            
                        }
                        
                    }
                    
                }
                
                
                
                Section("Mensagem") {
                    
                    TextEditor(text: $texto).frame(minHeight: 140)
                    
                }
                
                
                
                Button {
                    
                    Task { await salvar() }
                    
                } label: {
                    
                    HStack {
                        
                        Spacer()
                        
                        if saving { ProgressView() } else { Text("Salvar").bold() }
                        
                        Spacer()
                        
                    }
                    
                }
                
                .disabled(!podeSalvar || saving)
                
            }
            
            .navigationTitle("Editar publicacao")
            
            .toolbar {
                
                ToolbarItem(placement: .cancellationAction) {
                    
                    Button("Cancelar") { dismiss() }
                    
                }
                
            }
            
            .alert("Erro", isPresented: Binding(get: { !errorMessage.isEmpty }, set: { if !$0 { errorMessage = "" } })) {
                
                Button("OK") { errorMessage = "" }
                
            } message: { Text(errorMessage) }
            
                .onAppear {
                    
                    texto = postagem.text
                    
                    destino = postagem.destino ?? "@geral"
                    
                    cursoEscolhido = postagem.cursoDestino ?? ""
                    
                }
            
        }
        
    }
    
    
    
    private var podeSalvar: Bool {
        
        if texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        
        if destino == "@curso" && cursoEscolhido.isEmpty { return false }
        
        return true
        
    }
    
    
    
    private func salvar() async {
        
        saving = true
        
        defer { saving = false }
        
        
        
        var atualizada = postagem
        
        let mencao = destino == "@geral" ? "@geral" : "@\(cursoEscolhido)"
        
        let textoLimpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let textoFinal = textoLimpo.hasPrefix("@") ? textoLimpo : "\(mencao) \(textoLimpo)"
        
        
        
        atualizada.text = textoFinal
        
        atualizada.destino = destino
        
        atualizada.cursoDestino = destino == "@geral" ? nil : cursoEscolhido
        
        
        
        do {
            
            try await APIService.shared.atualizar(atualizada)
            
            onSaved()
            
            dismiss()
            
        } catch {
            
            errorMessage = error.localizedDescription
            
        }
        
    }
    
}



struct EditarAnuncioView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    let anuncio: Anuncio
    
    let onSaved: () -> Void
    
    
    
    @State private var type = ""
    
    @State private var title = ""
    
    @State private var description = ""
    
    @State private var destino = "@geral"
    
    @State private var cursoEscolhido = ""
    
    @State private var saving = false
    
    @State private var errorMessage = ""
    
    
    
    private let categorias = ["Material", "Residencia", "Servico", "Outro"]
    
    private let cursos = Cursos.lista
    
    
    
    var body: some View {
        
        NavigationStack {
            
            Form {
                
                Picker("Categoria", selection: $type) {
                    
                    ForEach(categorias, id: \.self) { Text($0) }
                    
                }
                
                
                
                Section("Destino do anuncio") {
                    
                    Picker("Notificar", selection: $destino) {
                        
                        Text("Todos (@geral)").tag("@geral")
                        
                        Text("Curso especifico (@curso)").tag("@curso")
                        
                    }
                    
                    .pickerStyle(.segmented)
                    
                    
                    
                    if destino == "@curso" {
                        
                        Picker("Escolha o curso", selection: $cursoEscolhido) {
                            
                            Text("Selecione um curso").tag("")
                            
                            ForEach(cursos, id: \.self) { Text($0).tag($0) }
                            
                        }
                        
                    }
                    
                }
                
                
                
                Section("Detalhes") {
                    
                    TextField("Titulo", text: $title)
                    
                    TextEditor(text: $description)
                    
                        .frame(minHeight: 120)
                    
                }
                
                
                
                Button {
                    
                    Task { await salvar() }
                    
                } label: {
                    
                    HStack {
                        
                        Spacer()
                        
                        if saving { ProgressView() } else { Text("Salvar").bold() }
                        
                        Spacer()
                        
                    }
                    
                }
                
                .disabled(!podeSalvar || saving)
                
            }
            
            .navigationTitle("Editar anuncio")
            
            .toolbar {
                
                ToolbarItem(placement: .cancellationAction) {
                    
                    Button("Cancelar") { dismiss() }
                    
                }
                
            }
            
            .alert("Erro", isPresented: Binding(get: { !errorMessage.isEmpty }, set: { if !$0 { errorMessage = "" } })) {
                
                Button("OK") { errorMessage = "" }
                
            } message: { Text(errorMessage) }
            
                .onAppear {
                    
                    type = anuncio.anuncioType
                    
                    title = anuncio.title
                    
                    description = anuncio.description
                    
                    destino = anuncio.destino ?? "@geral"
                    
                    cursoEscolhido = anuncio.cursoDestino ?? ""
                    
                    if destino == "@curso" && cursoEscolhido.isEmpty {
                        
                        cursoEscolhido = anuncio.course
                        
                    }
                    
                }
            
        }
        
    }
    
    
    
    private var podeSalvar: Bool {
        
        if title.isEmpty || description.isEmpty { return false }
        
        if destino == "@curso" && cursoEscolhido.isEmpty { return false }
        
        return true
        
    }
    
    
    
    private func salvar() async {
        
        saving = true
        
        defer { saving = false }
        
        
        
        let cursoFinal = destino == "@geral" ? "Geral / Todos" : cursoEscolhido
        
        var atualizado = anuncio
        
        atualizado.anuncioType = type
        
        atualizado.title = title
        
        atualizado.description = description
        
        atualizado.course = cursoFinal
        
        atualizado.destino = destino
        
        atualizado.cursoDestino = destino == "@geral" ? nil : cursoEscolhido
        
        do {
            
            try await APIService.shared.atualizar(atualizado)
            
            onSaved()
            
            dismiss()
            
        } catch {
            
            errorMessage = error.localizedDescription
            
        }
        
    }
    
}

struct ConfiguracoesView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    let usuarioId: String
    
    @Binding var receberGeral: Bool
    
    @Binding var receberCursos: Bool
    
    @State private var salvando = false
    
    @State private var mensagem = ""
    
    @State private var erro = ""
    
    var body: some View {
        
        NavigationStack {
            
            Form {
                
                Section("Notificacoes") {
                    
                    Toggle("Receber avisos de @geral", isOn: $receberGeral)
                    
                    Toggle("Receber avisos de cursos", isOn: $receberCursos)
                    
                }
                
                Section {
                    
                    Button {
                        
                        Task { await salvar() }
                        
                    } label: {
                        
                        HStack {
                            
                            Spacer()
                            
                            if salvando { ProgressView() }
                            
                            else { Text("Salvar configuracoes").bold() }
                            
                            Spacer()
                            
                        }
                        
                    }
                    
                    .disabled(salvando || usuarioId.isEmpty)
                    
                }
                
                
                
                if !mensagem.isEmpty {
                    
                    Section {
                        
                        Label(mensagem, systemImage: "checkmark.circle.fill")
                        
                            .foregroundStyle(.green)
                        
                    }
                    
                }
                
            }
            
            .navigationTitle("Configuracoes")
            
            .toolbar {
                
                ToolbarItem(placement: .cancellationAction) {
                    
                    Button("Fechar") { dismiss() }
                    
                }
                
            }
            
            .alert("Erro", isPresented: Binding(get: { !erro.isEmpty }, set: { if !$0 { erro = "" } })) {
                
                Button("OK") { erro = "" }
                
            } message: { Text(erro) }
            
        }
        
    }
    
    private func salvar() async {
        
        salvando = true
        
        mensagem = ""
        
        defer { salvando = false }
        
        do {
            
            if !APIConfig.usarDadosLocais {
                
                try await APIService.shared.atualizarPreferencias(
                    
                    usuarioId: usuarioId,
                    
                    receberGeral: receberGeral,
                    
                    receberCursos: receberCursos
                    
                )
                
            }
            
            mensagem = "Configuracoes salvas com sucesso."
            
        } catch {
            
            erro = error.localizedDescription
            
        }
        
    }
    
}


enum Cursos {
    
    static let lista = [
        
        "Administracao",
        
        "Ciencia da Computacao",
        
        "Ciencias Biologicas",
        
        "Ciencias Contabeis",
        
        "Ciencias Economicas",
        
        "Enfermagem",
        
        "Engenharia Agricola",
        
        "Engenharia Civil",
        
        "Farmacia",
        
        "Fisioterapia",
        
        "Geografia",
        
        "Historia",
        
        "Letras - Port./Espanhol",
        
        "Letras - Port./Ingles",
        
        "Matematica",
        
        "Medicina",
        
        "Odontologia",
        
        "Pedagogia",
        
        "Tecnologia em Design Educacional",
        
        "Outro / Setor Administrativo"
        
    ]
    
}



struct EmptyStateView: View {
    
    let icon: String
    
    let title: String
    
    let message: String
    
    
    
    var body: some View {
        
        VStack(spacing: 14) {
            
            Image(systemName: icon)
            
                .font(.system(size: 48))
            
                .foregroundStyle(.blue)
            
            Text(title).font(.title3.bold())
            
            Text(message)
            
                .foregroundStyle(.secondary)
            
                .multilineTextAlignment(.center)
            
                .padding(.horizontal, 35)
            
        }
        
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        
    }
    
}


#Preview {
    
    ContentView()
    
}
