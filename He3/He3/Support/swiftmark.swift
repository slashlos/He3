/// https://github.com/ntrupin/swiftmark

import Foundation

/// A simple, lightweight Markdown parser.
class swiftmark {
    
  /// The class-scope variable that stores user-defined Markdown.
  var markdown = String()
    
    /**
     Initializes a new Markdown parser with the text to be parsed.

     `init` does not require that a value be given for the parameter
     markdown. If no value is passed, `swiftmark` will default
     to an empty string (`""`)
     
     However, passing a value of `nil` for the parameter `markdown`
     will prevent the program from compiling.
     
     Initialization of `swiftmark` simply requires referencing the
     class and implicitly providing a string containing Markdown
     (optional).
     
     ```
     // with value
     let sm = swiftmark("# Markdown")
     // or, without value
     let sm = swiftmark()
     ```
     
    `swiftmark` also accept multi-line strings being passed to
    `init`
     
     ```
     let sm = swiftmark("""
     # Markdown
     Multi-line string.
     """)
     ```
     
     - Parameters:
        - markdown: (**Implicit**) The Markdown to be
                    parsed.

     - Returns: The initialized `swiftmark` class.
     - Precondition: `markdown` must not be `nil`.
    */
  init(_ markdown: String = "") {
    self.markdown = markdown
  }

    /**
     Parses Markdown into HTML.

     Calling this method converts the Markdown passed in `init`
     to an HTML string. The function does not accept any arguments
     itself.
     
     The  `html` function requires that `swiftmark` be initialized
     with a non-nil value, and can be called either at the same time
     as or after the initialization.
     
     ```
     // Same time
     let html = swiftmark("# Markdown").html()
     // After
     let sm = swiftmark("# Markdown")
     let html = sm.html()
     ```
     
     - Returns: The parsed HTML.
     - Precondition: `markdown` must not be `nil`.
    */
  func html() -> String {
    convert_headers()
    convert_strong()
    convert_italic()
    convert_strike()
    convert_code()
    convert_codeblock()
    convert_img()
    convert_links()
    convert_ulists()
    convert_olists()
    return markdown
  }

  private func convert_headers() {
    if let range = self.markdown.range(of: #"(?m)^#{1,6}.*$"#, options: .regularExpression) {
      var weight = 0;
      for hashtag in markdown[range].replacingOccurrences(of:"#", with: "#,").split(separator: ",") {
        if hashtag != "#" {
          break
        }
        weight+=1
      }
      let content = self.markdown[range].replacingOccurrences(of: #"(?m)^#{1,6}"#, with: "", options: .regularExpression)
      self.markdown = markdown.replacingOccurrences(of: markdown[range], with: "<h\(weight)>\(content.trimmingCharacters(in: .whitespacesAndNewlines))</h\(weight)>")
    }
    if self.markdown.range(of: #"(?m)^#{1,6}.*$"#, options: .regularExpression) != nil {
      self.convert_headers()
    }
  }

  private func convert_strong() {
    if let range = self.markdown.range(of: #"(?m)\*{2}(\w|\s)+\*{2}|_{2}(\w|\s)+_{2}"#, options: .regularExpression) {
      let content = self.markdown[range].replacingOccurrences(of: #"(?m)\*{2}|_{2}"#, with: "", options: .regularExpression)
      self.markdown = markdown.replacingOccurrences(of: markdown[range], with: "<strong>\(content)</strong>")
    }
    if self.markdown.range(of: #"(?m)\*{2}(\w|\s)+\*{2}|_{2}(\w|\s)+_{2}"#, options: .regularExpression) != nil {
      self.convert_strong()
    }
  }

  private func convert_italic() {
    if let range = self.markdown.range(of: #"(?m)\*{1}(\w|\s)+\*{1}|_{1}(\w|\s)+_{1}"#, options: .regularExpression) {
      let content = self.markdown[range].replacingOccurrences(of: #"(?m)\*{1}|_{1}"#, with: "", options: .regularExpression)
      self.markdown = markdown.replacingOccurrences(of: markdown[range], with: "<em>\(content)</em>")
    }
    if self.markdown.range(of: #"(?m)\*{1}(\w|\s)+\*{1}|_{1}(\w|\s)+_{1}"#, options: .regularExpression) != nil {
      self.convert_italic()
    }
  }

  private func convert_strike() {
    if let range = self.markdown.range(of: #"(?m)~(\w|\s)+~"#, options: .regularExpression) {
      let content = self.markdown[range].replacingOccurrences(of: #"(?m)~"#, with: "", options: .regularExpression)
      self.markdown = markdown.replacingOccurrences(of: markdown[range], with: "<strike>\(content)</strike>")
    }
    if self.markdown.range(of: #"(?m)~(\w|\s)+~"#, options: .regularExpression) != nil {
      self.convert_strike()
    }
  }

  private func convert_code() {
    if let range = self.markdown.range(of: #"(?m)`(\w|\s)+`"#, options: .regularExpression) {
      let content = self.markdown[range].replacingOccurrences(of: #"(?m)`"#, with: "", options: .regularExpression)
      self.markdown = markdown.replacingOccurrences(of: markdown[range], with: "<code>\(content)</code>")
    }
    if self.markdown.range(of: #"(?m)`(\w|\s)+`"#, options: .regularExpression) != nil {
      self.convert_code()
    }
  }

  private func convert_codeblock() {
    if let range = self.markdown.range(of: #"(?m)```\w*(.*(\r\n|\r|\n))+```"#, options: .regularExpression) {
      let lpass = self.markdown.range(of: #"(?m)```.*$"#, options: .regularExpression)
      let lang = self.markdown[lpass!].replacingOccurrences(of: #"(?m)`"#, with: "", options: .regularExpression)
      let content = self.markdown[range].replacingOccurrences(of: #"```\w+"#, with: "```", options: .regularExpression).replacingOccurrences(of: #"(?m)`"#, with: "", options: .regularExpression)
      self.markdown = markdown.replacingOccurrences(of: markdown[range], with: "<pre class=\"\(lang)\"><code>\(content)</code></pre>")
    }
    if self.markdown.range(of: #"(?m)```\w*(.*(\r\n|\r|\n))+```"#, options: .regularExpression) != nil {
      self.convert_codeblock()
    }
  }

  private func convert_links() {
    if let range = self.markdown.range(of: #"(?:__|[*#])|\]\((.*?)\)"#, options: .regularExpression), let range2 = self.markdown.range(of: #"(?:__|[*#])|\[(.*?)\]"#, options: .regularExpression) {
      let nrange = markdown[range2] + markdown[range].replacingOccurrences(of: #"\]"#, with: "", options: .regularExpression)
      let hpass = self.markdown.range(of: #"(?:__|[*#])|\]\(.*?\)"#, options: .regularExpression)
      let href = self.markdown[hpass!].replacingOccurrences(of: #"(?m)\]\(|\)"#, with: "", options: .regularExpression)
      let lpass = self.markdown.range(of: #"(?:__|[*#])|\[(.*?)\]"#, options: .regularExpression)
      let link_text = self.markdown[lpass!].replacingOccurrences(of: #"(?m)[\[\]]"#, with: "", options: .regularExpression)
      self.markdown = markdown.replacingOccurrences(of: nrange, with: "<a href=\"\(href)\">\(link_text)</a>")
    }
    if self.markdown.range(of: #"(?:__|[*#])|\]\((.*?)\)"#, options: .regularExpression) != nil && self.markdown.range(of: #"(?:__|[*#])|\[(.*?)\]"#, options: .regularExpression) != nil {
      self.convert_links()
    }
  }

  private func convert_ulists() {
    if let _ = self.markdown.range(of: #"(?m)(\-.+(\r|\n|\r\n))+"#, options: .regularExpression) {
      var items = "<ul>\n"
      var olds = ""
      var goto = Goto()
      goto.set("loopu") {
        if let lrange = self.markdown.range(of: #"(?m)\-.+"#, options: .regularExpression) {
          olds = olds + "\(self.markdown[lrange])\n"
          items = items + "<li>\(self.markdown[lrange].replacingOccurrences(of: #"^\-(\s?)"#, with: "", options: .regularExpression))</li>\n"

          if self.markdown.range(of: #"(?m)(\-.+(\r|\n|\r\n))+"#, options: .regularExpression) != nil {
            self.markdown = self.markdown.replacingOccurrences(of: "\(self.markdown[lrange])\n", with: "<li>\(self.markdown[lrange].replacingOccurrences(of: #"^\-(\s?)"#, with: "", options: .regularExpression))</li>\n")
            goto • "loopu"
          }
        }
      }
      goto.set("endu") {
        return
      }
      if self.markdown.range(of: #"(?m)(\-.+(\r|\n|\r\n))+"#, options: .regularExpression) != nil {
        goto • "loopu"
      }
      self.markdown = self.markdown.replacingOccurrences(of: items.replacingOccurrences(of: "<ul>\n", with: ""), with: items + "</ul>\n")
    }
    if self.markdown.range(of: #"(?m)(\-.+(\r|\n|\r\n))+"#, options: .regularExpression) != nil {
      self.convert_ulists()
    }
  }

  private func convert_olists() {
    if let _ = self.markdown.range(of: #"(?m)(\d\..+(\r|\n|\r\n))+"#, options: .regularExpression) {
      var items = "<ol>\n"
      var olds = ""
      var goto = Goto()
      goto.set("loopo") {
        if let lrange = self.markdown.range(of: #"(?m)\d\..+"#, options: .regularExpression) {
          olds = olds + "\(self.markdown[lrange])\n"
          items = items + "<li>\(self.markdown[lrange].replacingOccurrences(of: #"^\d\.(\s?)"#, with: "", options: .regularExpression))</li>\n"

          if self.markdown.range(of: #"(?m)(\d\..+(\r|\n|\r\n))+"#, options: .regularExpression) != nil {
            self.markdown = self.markdown.replacingOccurrences(of: "\(self.markdown[lrange])\n", with: "<li>\(self.markdown[lrange].replacingOccurrences(of: #"\d\.(\s?)"#, with: "", options: .regularExpression))</li>\n")
            goto • "loopo"
          }

        }
      }
      goto.set("endo") {
        return
      }
      if self.markdown.range(of: #"(?m)(\d\..+(\r|\n|\r\n))+"#, options: .regularExpression) != nil {
        goto • "loopo"
      }
      self.markdown = self.markdown.replacingOccurrences(of: items.replacingOccurrences(of: "<ol>\n", with: ""), with: items + "</ol>\n").replacingOccurrences(of: "<ul>\n<ol>", with: "<ul>").replacingOccurrences(of: "</ol>\n</ul>", with: "</ul>")
    }
    if self.markdown.range(of: #"(?m)(\d\..+(\r|\n|\r\n))+"#, options: .regularExpression) != nil {
      self.convert_olists()
    }
  }
    
  private func convert_img() {
    if let range = self.markdown.range(of: #"(?:__|[*#])|\]\((.*?)\)"#, options: .regularExpression), let range2 = self.markdown.range(of: #"(?:__|[*#])|\!\[(.*?)\]"#, options: .regularExpression) {
      let nrange = markdown[range2] + markdown[range].replacingOccurrences(of: #"\]"#, with: "", options: .regularExpression)
      let hpass = self.markdown.range(of: #"(?:__|[*#])|\]\(.*?\)"#, options: .regularExpression)
      let href = self.markdown[hpass!].replacingOccurrences(of: #"(?m)\]\(|\)"#, with: "", options: .regularExpression)
      let apass = self.markdown.range(of: #"(?:__|[*#])|\!\[(.*?)\]"#, options: .regularExpression)
      let alt = self.markdown[apass!].replacingOccurrences(of: #"(?m)[\!\[\]]"#, with: "", options: .regularExpression)
      self.markdown = markdown.replacingOccurrences(of: nrange, with: "<img src=\"\(href)\" alt=\"\(alt)\" />")
    }
    if self.markdown.range(of: #"(?:__|[*#])|\]\((.*?)\)"#, options: .regularExpression) != nil && self.markdown.range(of: #"(?:__|[*#])|\!\[(.*?)\]"#, options: .regularExpression) != nil {
      self.convert_img()
    }
  }
}


//infix operator • { associativity left precedence 140 }
precedencegroup MultiplicationPrecedence {
  associativity: left
  higherThan: AdditionPrecedence
}
infix operator • : MultiplicationPrecedence
fileprivate func •(goto: Goto, label: String) {
  goto.call(label)
}

fileprivate struct Goto {
  typealias Closure = () -> Void
  var closures = [String: Closure]()
  mutating func set(_ label: String, closure: @escaping Closure) {
    closures[label] = closure
  }
  func call(_ label: String) {
    closures[label]?()
  }
}
