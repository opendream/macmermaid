import Foundation

struct DiagramTemplate: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let source: String

    static let welcome = DiagramTemplate(id: "welcome", title: "A little clarity", subtitle: "Turn an idea into something you can see.", symbol: "point.3.connected.trianglepath.dotted", source: """
    %% A little clarity, one connection at a time.
    flowchart TD
        idea([A bright idea]) --> sketch[Write it down]
        sketch --> question{Does it connect?}
        question -->|Yes| clarity[Find the clarity]
        question -->|Not yet| explore[Explore a little]
        explore --> sketch
        clarity --> share([Share your thinking])

        classDef highlight fill:#d5f5ec,stroke:#279e86,color:#173f38
        class idea,share highlight
    """)

    static let all: [DiagramTemplate] = [
        welcome,
        .init(id: "flowchart", title: "Flowchart", subtitle: "Decisions, steps, and possibilities.", symbol: "arrow.triangle.branch", source: """
        flowchart LR
            A([Start]) --> B[Gather ideas]
            B --> C{Ready?}
            C -->|Yes| D[Make it happen]
            C -->|Not yet| B
            D --> E([Done])
        """),
        .init(id: "sequence", title: "Sequence", subtitle: "A conversation between systems.", symbol: "arrow.left.arrow.right", source: """
        sequenceDiagram
            autonumber
            actor You
            participant App as MacMermaid
            participant Engine as Mermaid
            You->>App: Write an idea
            App->>Engine: Render diagram
            Engine-->>App: Beautiful SVG
            App-->>You: See it come to life
        """),
        .init(id: "class", title: "Class diagram", subtitle: "Give your objects some structure.", symbol: "square.stack.3d.up", source: """
        classDiagram
            Project "1" --> "many" Diagram
            Diagram --> Renderer
            class Project {
                +String name
                +addDiagram()
            }
            class Diagram {
                +String source
                +save()
            }
            class Renderer {
                +render(source) SVG
            }
        """),
        .init(id: "state", title: "State machine", subtitle: "Map what happens next.", symbol: "circle.hexagongrid", source: """
        stateDiagram-v2
            [*] --> Draft
            Draft --> Reviewing: Submit
            Reviewing --> Draft: Revise
            Reviewing --> Published: Approve
            Published --> Archived
            Archived --> [*]
        """),
        .init(id: "er", title: "Relationships", subtitle: "Connect the dots in your data.", symbol: "externaldrive.connected.to.line.below", source: """
        erDiagram
            PROJECT ||--o{ DIAGRAM : contains
            DIAGRAM ||--o{ REVISION : tracks
            PROJECT {
                int id PK
                string name
            }
            DIAGRAM {
                int id PK
                string source
            }
            REVISION {
                datetime saved_at
                string content
            }
        """),
        .init(id: "mindmap", title: "Mind map", subtitle: "Make room for a bigger idea.", symbol: "brain", source: """
        mindmap
          root((A new idea))
            Why
              The problem
              The opportunity
            What
              A simple solution
              A delightful detail
            How
              Sketch
              Build
              Share
        """),
        .init(id: "gantt", title: "Project plan", subtitle: "Put your next chapter on a timeline.", symbol: "chart.bar.xaxis", source: """
        gantt
            title The next big thing
            dateFormat YYYY-MM-DD
            section Discover
            Research :a, 2026-10-19, 4d
            Sketch   :b, after a, 3d
            section Create
            Build    :c, after b, 8d
            Polish   :d, after c, 3d
            Launch   :milestone, after d, 0d
        """),
        .init(id: "pie", title: "Pie chart", subtitle: "See the parts of a whole.", symbol: "chart.pie", source: """
        pie showData
            title A balanced day
            "Creating" : 45
            "Learning" : 25
            "Connecting" : 20
            "Daydreaming" : 10
        """),
        .init(id: "git", title: "Git branches", subtitle: "A history of making things better.", symbol: "point.3.filled.connected.trianglepath.dotted", source: """
        gitGraph
            commit id: "An idea"
            branch feature
            checkout feature
            commit id: "First draft"
            commit id: "Polish"
            checkout main
            merge feature
            commit id: "Ship it"
        """),
        .init(id: "journey", title: "User journey", subtitle: "Understand the experience.", symbol: "figure.walk", source: """
        journey
            title From thought to diagram
            section Explore
              Have an idea: 5: You
              Find the words: 3: You
            section Create
              Write a diagram: 4: You
              See it live: 5: You, MacMermaid
              Share it: 5: You
        """),
        .init(id: "timeline", title: "Timeline", subtitle: "Tell a story in moments.", symbol: "clock", source: """
        timeline
            title An idea takes shape
            Monday : A spark of inspiration
            Tuesday : Sketch the possibilities
            Wednesday : Build something small
            Thursday : Make it better
            Friday : Share it with the world
        """)
    ]
}
