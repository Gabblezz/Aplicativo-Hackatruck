//
//  ContentView.swift
//  ProjetoFinal
//
//  Created by Turma01-13 on 11/09/26.
//

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
    
    let listaCursos = [
        "Administração",
        "Ciência da Computação",
        "Ciências Biológicas",
        "Ciências Contábeis",
        "Ciências Econômicas",
        "Enfermagem",
        "Engenharia Agrícola",
        "Engenharia Civil",
        "Farmácia",
        "Fisioterapia",
        "Geografia",
        "História",
        "Letras - Port./Espanhol",
        "Letras - Port./Inglês",
        "Letras - Port./Italiano",
        "Matemática",
        "Medicina",
        "Odontologia",
        "Pedagogia",
        "Tecnologia em Design Educacional",
        "Outro / Setor Administrativo"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Dados Pessoais")) {
                    TextField("Nome Completo", text: $name)
                    
                    // CORREÇÃO AQUI: Ajustada a sintaxe do fechamento do ForEach usando 'curso in'
                    Picker("Curso / Setor", selection: $course) {
                        Text("Selecione uma opção").tag("")
                        ForEach(listaCursos, id: \.self) { curso in
                            Text(curso).tag(curso)
                        }
                    }
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
                                Text(post.text)
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
        }
    }
}

struct ClassificadosView: View {
    @Binding var anuncios: [Anuncio]
    var body: some View { Text("Tela de Classificados") }
}

struct AreaExclusivaView: View {
    @Binding var userRole: String
    @Binding var isProfileCompleted: Bool
    var body: some View { Text("Área do Usuário") }
}

