import SwiftUI

struct Anuncio: Identifiable {
    let id = UUID()
    let type: String
    let title: String
    let description: String
    let course: String
}

struct PostagemMural: Identifiable {
    let id = UUID()
    let authorName: String
    let authorRole: String
    let authorCourse: String
    let text: String
    let timestamp: Date = Date()
}

struct ContentView: View {
    @AppStorage("userRole") private var userRole: String = ""
    @AppStorage("isProfileCompleted") private var isProfileCompleted: Bool = false

    var body: some View {
        if userRole.isEmpty {
            RoleSelectionView(userRole: $userRole)
        } else if !isProfileCompleted {
            CompleteInfoView(isProfileCompleted: $isProfileCompleted)
        } else {
            MainDashboardView(userRole: $userRole, isProfileCompleted: $isProfileCompleted)
        }
    }
}

struct RoleSelectionView: View {
    @Binding var userRole: String
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Selecione seu perfil")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 20)
            
            roleButton(title: "Sou Aluno", role: "aluno", color: .blue)
            roleButton(title: "Sou Professor", role: "professor", color: .pink)
            roleButton(title: "Sou Agente Universitário", role: "agente", color: .red)
        }
        .padding()
    }
    
    @ViewBuilder
    private func roleButton(title: String, role: String, color: Color) -> some View {
        Button(action: {
            withAnimation {
                userRole = role
            }
        }) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(color)
                .cornerRadius(12)
                .padding(.horizontal, 20)
        }
    }
}

struct CompleteInfoView: View {
    @Binding var isProfileCompleted: Bool
    
    @State private var name: String = ""
    @State private var course: String = ""
    @State private var notifyAlerts: Bool = false
    @State private var notifyEvents: Bool = false
    @State private var notifyClassifieds: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Dados Pessoais")) {
                    TextField("Nome Completo", text: $name)
                    TextField("Curso / Setor", text: $course)
                }
                
                Section(header: Text("Preferências de Notificação")) {
                    Toggle("Quero receber notificações de avisos, editais e bolsas", isOn: $notifyAlerts)
                    Toggle("Quero receber notificações de eventos", isOn: $notifyEvents)
                    Toggle("Quero receber notificações de classificados", isOn: $notifyClassifieds)
                }
                
                Section {
                    Button(action: {
                        withAnimation {
                            isProfileCompleted = true
                        }
                    }) {
                        Text("Concluir Cadastro")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.blue)
                    .disabled(name.isEmpty || course.isEmpty)
                    .opacity(name.isEmpty || course.isEmpty ? 0.6 : 1.0)
                }
            }
            .navigationTitle("Complete seu Perfil")
        }
    }
}

struct MainDashboardView: View {
    @Binding var userRole: String
    @Binding var isProfileCompleted: Bool
    
    @State private var anuncios: [Anuncio] = [
        Anuncio(type: "Residência", title: "Quarto próximo ao campus", description: "Incluso água, luz e internet. Mobiliado.", course: "Geral / Todos"),
        Anuncio(type: "Material", title: "Cálculo A - Stewart (7ª Ed.)", description: "Livro em ótimo estado, sem rasuras.", course: "Engenharia")
    ]
    
    @State private var postagens: [PostagemMural] = []
    
    var body: some View {
        TabView {
            MuralGeralView(postagens: $postagens, userRole: $userRole)
                .tabItem {
                    Label("Mural Geral", systemImage: "megaphone.fill")
                }
            
            ClassificadosView(anuncios: $anuncios)
                .tabItem {
                    Label("Classificados", systemImage: "cart.fill")
                }
            
            AreaExclusivaView(userRole: $userRole, isProfileCompleted: $isProfileCompleted)
                .tabItem {
                    Label("Para Você", systemImage: "person.text.rectangle.fill")
                }
        }
    }
}

struct MuralGeralView: View {
    @Binding var postagens: [PostagemMural]
    @Binding var userRole: String
    @State private var showingPostModal = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                if postagens.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "megaphone")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        Text("Nenhuma postagem no mural")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Seja o primeiro a publicar um aviso para o campus.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(postagens) { post in
                                WhatsAppMessageCard(post: post)
                            }
                        }
                        .padding()
                    }
                }
                
                Button(action: {
                    showingPostModal = true
                }) {
                    Image(systemName: "plus")
                        .font(.title.weight(.semibold))
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding()
            }
            .navigationTitle("Mural Geral")
            .sheet(isPresented: $showingPostModal) {
                NovaPostagemView(postagens: $postagens, userRole: userRole)
            }
        }
    }
}

struct WhatsAppMessageCard: View {
    let post: PostagemMural
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(post.authorName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(roleColor)
                    
                    Text("• \(post.authorCourse)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(post.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Text(post.text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        }
        .padding(.horizontal, 4)
    }
    
    private var roleColor: Color {
        switch post.authorRole {
        case "professor": return .pink
        case "agente": return .red
        default: return .blue
        }
    }
}

struct NovaPostagemView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var postagens: [PostagemMural]
    let userRole: String
    
    @State private var authorName = ""
    @State private var authorCourse = ""
    @State private var text = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Suas Informações")) {
                    TextField("Seu Nome", text: $authorName)
                    TextField("Seu Curso / Setor", text: $authorCourse)
                }
                
                Section(header: Text("Mensagem para o Mural")) {
                    TextField("Digite sua postagem...", text: $text, axis: .vertical)
                        .lineLimit(4...6)
                }
                
                Section {
                    Button("Publicar Aviso") {
                        let novaPostagem = PostagemMural(
                            authorName: authorName,
                            authorRole: userRole,
                            authorCourse: authorCourse,
                            text: text
                        )
                        postagens.insert(novaPostagem, at: 0)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                    .disabled(authorName.isEmpty || authorCourse.isEmpty || text.isEmpty)
                }
            }
            .navigationTitle("Novo Aviso")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ClassificadosView: View {
    @Binding var anuncios: [Anuncio]
    @State private var selectedTab = 0
    @State private var showingAddModal = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("Categorias", selection: $selectedTab) {
                    Text("Residências").tag(0)
                    Text("Materiais").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                let tipoAtual = selectedTab == 0 ? "Residência" : "Material"
                let itensFiltrados = anuncios.filter { $0.type == tipoAtual }
                
                if itensFiltrados.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: selectedTab == 0 ? "house.fill" : "book.fill")
                            .font(.largeTitle)
                            .foregroundColor(selectedTab == 0 ? .blue : .green)
                        Text(selectedTab == 0 ? "Nenhuma residência anunciada" : "Nenhum material anunciado")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(itensFiltrados) { anuncio in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(anuncio.title)
                                    .font(.headline)
                                Text(anuncio.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Curso: \(anuncio.course)")
                                    .font(.caption)
                                    .padding(.top, 2)
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Classificados")
            .toolbar {
                Button(action: { showingAddModal = true }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddModal) {
                NovoAnuncioView(anuncios: $anuncios)
            }
        }
    }
}

struct NovoAnuncioView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var anuncios: [Anuncio]
    
    @State private var typeSelection = "Residência"
    @State private var title = ""
    @State private var description = ""
    @State private var courseSelection = "Geral / Todos"
    
    let courses = ["Geral / Todos", "Engenharia", "Medicina", "Direito", "Ciência da Computação", "Administração"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Tipo do Anúncio")) {
                    Picker("Tipo", selection: $typeSelection) {
                        Text("Residência").tag("Residência")
                        Text("Material").tag("Material")
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Informações")) {
                    TextField("Título do anúncio", text: $title)
                    TextField("Descrição detalhada", text: $description)
                }
                
                Section(header: Text("Curso Relacionado")) {
                    Picker("Selecione o Curso", selection: $courseSelection) {
                        ForEach(courses, id: \.self) { course in
                            Text(course)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                Section {
                    Button("Publicar Anúncio") {
                        let novo = Anuncio(
                            type: typeSelection,
                            title: title,
                            description: description,
                            course: courseSelection
                        )
                        anuncios.append(novo)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                    .disabled(title.isEmpty || description.isEmpty)
                }
            }
            .navigationTitle("Criar Anúncio")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AreaExclusivaView: View {
    @Binding var userRole: String
    @Binding var isProfileCompleted: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Área do \(roleFormattedName)")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text("Conteúdo exclusivo para o seu perfil.")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Area Restrita")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation {
                            userRole = ""
                            isProfileCompleted = false
                        }
                    }) {
                        Label("Alterar Perfil", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
    }
    
    private var roleFormattedName: String {
        switch userRole {
        case "aluno": return "Aluno"
        case "professor": return "Professor"
        case "agente": return "Agente Universitário"
        default: return "Usuário"
        }
    }
}

#Preview {
    ContentView()
}
