import ArgumentParser
import CliDoc
import Rainbow

protocol CommandRepresentable: AsyncParsableCommand {
  static var commandName: String { get }
  static var parentCommand: String? { get }
}

extension CommandRepresentable {

  static var parentCommand: String? { nil }

  static func makeExample(
    label: String,
    example: String,
    includesAppName: Bool = true
  ) -> AppExample {
    .init(
      label: label,
      parentCommand: parentCommand,
      commandName: commandName,
      includesAppName: includesAppName,
      example: example
    )
  }
}

extension Abstract where Content == String {
  static func `default`(_ string: String) -> Self {
    .init { string.blue }
  }
}

struct Note<Content: TextNode>: TextNode {
  let content: Content

  init(
    @TextBuilder _ content: () -> Content
  ) {
    self.content = content()
  }

  var body: some TextNode {
    LabeledContent {
      content.italic()
    } label: {
      "Note:".yellow.bold
    }
    .style(.vertical())
  }
}

extension Note where Content == AnyTextNode {

  static func `default`(
    notes: [String],
    usesConfigurationFileNote: Bool = true,
    usesConfigurationMergingNote: Bool = true
  ) -> Self {
    var notes = notes

    if usesConfigurationFileNote {
      notes.insert(
        "Most options are not required when a configuration file is setup for your project.",
        at: 0
      )
    }

    if usesConfigurationMergingNote {
      if usesConfigurationFileNote {
        notes.insert(
          "Any configuration options get merged with the loaded project configuration file.",
          at: 1
        )
      } else {
        notes.insert(
          "Any configuration options get merged with the loaded project configuration file.",
          at: 0
        )
      }
    }

    return .init {
      VStack {
        notes.enumerated().map { "\($0 + 1). \($1)" }
      }
      .eraseToAnyTextNode()
    }
  }

}

extension Discussion where Content == AnyTextNode {
  static func `default`<Preamble: TextNode, Trailing: TextNode>(
    notes: [String] = [],
    examples: [AppExample]? = nil,
    usesExtraOptions: Bool = true,
    usesConfigurationFileNote: Bool = true,
    usesConfigurationMergingNote: Bool = true,
    @TextBuilder preamble: () -> Preamble,
    @TextBuilder trailing: () -> Trailing
  ) -> Self {
    Discussion {
      VStack {
        preamble().italic()

        Note.default(
          notes: notes,
          usesConfigurationFileNote: usesConfigurationFileNote,
          usesConfigurationMergingNote: usesConfigurationMergingNote
        )

        if let examples {
          ExampleSection.default(examples: examples, usesExtraOptions: usesExtraOptions)
        }

        trailing()
      }
      .separator(.newLine(count: 2))
      .eraseToAnyTextNode()
    }
  }

  static func `default`<Preamble: TextNode>(
    notes: [String] = [],
    examples: [AppExample]? = nil,
    usesExtraOptions: Bool = true,
    usesConfigurationFileNote: Bool = true,
    usesConfigurationMergingNote: Bool = true,
    @TextBuilder preamble: () -> Preamble
  ) -> Self {
    .default(
      notes: notes,
      examples: examples,
      usesExtraOptions: usesExtraOptions,
      usesConfigurationFileNote: usesConfigurationFileNote,
      usesConfigurationMergingNote: usesConfigurationMergingNote,
      preamble: preamble,
      trailing: {
        if usesExtraOptions {
          ImportantNote.extraOptionsNote
        } else {
          Empty()
        }
      }
    )
  }

  static func `default`(
    notes: [String] = [],
    examples: [AppExample]? = nil,
    usesExtraOptions: Bool = true,
    usesConfigurationFileNote: Bool = true,
    usesConfigurationMergingNote: Bool = true
  ) -> Self {
    .default(
      notes: notes,
      examples: examples,
      usesExtraOptions: usesExtraOptions,
      usesConfigurationFileNote: usesConfigurationFileNote,
      usesConfigurationMergingNote: usesConfigurationMergingNote,
      preamble: { Empty() },
      trailing: { Empty() }
    )
  }

}

extension ExampleSection where Header == String, Label == String {
  static func `default`(
    examples: [AppExample] = [],
    usesExtraOptions: Bool = true
  ) -> some TextNode {
    var examples: [AppExample] = examples
    if usesExtraOptions {
      examples = examples.appendingExtraOptionsExample()
    }

    return Self(
      "Examples:",
      label: "A few common usage examples.",
      examples: examples.map(\.example)
    )
    .style(AppExampleSectionStyle())
  }
}

struct AppExampleSectionStyle: ExampleSectionStyle {

  func render(content: ExampleSectionConfiguration) -> some TextNode {
    Section {
      VStack {
        content.examples.map { example in
          VStack {
            example.label.color(.green).bold()
            ShellCommand(example.example).style(.default)
          }
        }
      }
      .separator(.newLine(count: 2))
    } header: {
      HStack {
        content.title.color(.blue).bold()
        content.label.italic()
      }
    }
  }
}

struct AppExample {
  let label: String
  let parentCommand: String?
  let commandName: String
  let includesAppName: Bool
  let exampleText: String

  init(
    label: String,
    parentCommand: String? = nil,
    commandName: String,
    includesAppName: Bool = true,
    example exampleText: String
  ) {
    self.label = label
    self.parentCommand = parentCommand
    self.commandName = commandName
    self.includesAppName = includesAppName
    self.exampleText = exampleText
  }

  var example: Example {
    var exampleString = "\(commandName) \(exampleText)"
    if let parentCommand {
      exampleString = "\(parentCommand) \(exampleString)"
    }
    if includesAppName {
      exampleString = "\(Application.commandName) \(exampleString)"
    }
    return (label: label, example: exampleString)
  }
}

extension Array where Element == AppExample {

  func appendingExtraOptionsExample() -> Self {
    guard let first = first else { return self }
    var output = self
    output.append(.init(
      label: "Passing extra options to custom strategy.",
      parentCommand: first.parentCommand,
      commandName: first.commandName,
      includesAppName: first.includesAppName,
      example: "--custom-command -- git describe --tags --exact-match"
    ))
    return output
  }
}

struct ImportantNote<Content: TextNode>: TextNode {
  let content: Content

  init(
    @TextBuilder _ content: () -> Content
  ) {
    self.content = content()
  }

  var body: some TextNode {
    LabeledContent {
      content.italic()
    } label: {
      "Important Note:".red.bold
    }
    .style(.vertical())
  }
}

extension ImportantNote where Content == String {
  static var extraOptionsNote: Self {
    .init {
      """
      Extra options / flags for custom strategies must proceed a `--` or you may get an undefined option error.
      """
    }
  }
}

extension Usage where Content == AnyTextNode {
  static func `default`(parentCommand: String? = nil, commandName: String?) -> Self {
    var commandString = commandName == nil ? "" : "\(commandName!)"
    if let parentCommand {
      commandString = "\(parentCommand) \(commandString)"
    }
    commandString = commandString == "" ? "\(Application.commandName)" : "\(Application.commandName) \(commandString)"

    return .init {
      HStack {
        commandString.blue
        "[<options>]".green
        "--"
        "[<extra-options> ...]".cyan
      }
      .eraseToAnyTextNode()
    }
  }
}
