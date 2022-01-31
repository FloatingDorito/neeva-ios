# Neeva for iOS

Download on the [App Store](https://apps.apple.com/us/app/neeva-browser-search-engine/id1543288638).

## This branch (main)

This branch works with [Xcode 13.0](https://apps.apple.com/us/app/xcode/id497799835), Swift 5.5 and supports iOS 14.0 and above.

## Getting involved

Check out our [Contributor Guidelines](https://github.com/neevaco/neeva-ios/blob/main/CONTRIBUTING.md)

Want to contribute but don't know where to start? Here is a list of [good first issues](https://github.com/neevaco/neeva-ios/labels/good%20first%20issue).

## Building the code

1. Install the latest [Xcode developer tools](https://developer.apple.com/xcode/downloads/) from Apple.
1. Install Carthage, Node, and a Python 3 virtualenv for localization scripts:
   ```shell
   brew update
   brew install carthage
   brew install node
   pip3 install virtualenv
   ```
1. Clone the repository:
   ```shell
   git clone https://github.com/neevaco/neeva-ios.git
   ```
1. Pull in the project dependencies:
   ```shell
   cd neeva-ios
   sh ./bootstrap.sh
   ```
1. Open `Client.xcodeproj` in Xcode.
1. Build the `Client` scheme in Xcode.

## Building User Scripts

User Scripts (JavaScript injected into the `WKWebView`) are compiled, concatenated and minified using [webpack](https://webpack.js.org/). User Scripts to be aggregated are placed in the following directories:

```
/Client
|-- /Frontend
    |-- /UserContent
        |-- /UserScripts
            |-- /AllFrames
            |   |-- /AtDocumentEnd
            |   |-- /AtDocumentStart
            |-- /MainFrame
                |-- /AtDocumentEnd
                |-- /AtDocumentStart
```

This reduces the total possible number of User Scripts down to four. The compiled output from concatenating and minifying the User Scripts placed in these folders resides in `/Client/Assets` and are named accordingly:

- `AllFramesAtDocumentEnd.js`
- `AllFramesAtDocumentStart.js`
- `MainFrameAtDocumentEnd.js`
- `MainFrameAtDocumentStart.js`

To simplify the build process, these compiled files are checked-in to this repository. When adding or editing User Scripts, these files can be re-compiled with `webpack` manually. This requires Node.js to be installed and all required `npm` packages can be installed by running `npm install` in the root directory of the project. User Scripts can be compiled by running the following `npm` command in the root directory of the project:

```
npm run build
```

## Periphery

Periphery scans the project (currently just the `Client` code) for unused variables, constants, functions, structs, and classes.
To use Periphery, first install it using [Homebrew](https://brew.sh):

```sh
brew tap peripheryapp/periphery && brew install periphery
```

Then switch to the Periphery target in Xcode and build (⌘B). You‘ll get a large number of warnings as a result. Note that many of the warnings are either false positives (i.e. the constant is actually used somewhere in the project) or are due to parameters passed in iOS’s standard delegate pattern.

## History of the codebase

The Neeva browser stands on the shoulders of the excellent [Firefox for iOS](https://github.com/mozilla-mobile/firefox-ios) browser.
We forked on Feb 18 at [c23bd56293da4e2913e1d512ee559e784dd21e48](https://github.com/neevaco/neeva-ios/commit/c23bd56293da4e2913e1d512ee559e784dd21e48),
and the project has diverged substantially enough that it hasn't made sense to merge updates since.

Thank you to Mozilla for providing such a fantastic foundation for this project
and many others.

## For Neeva employees

### Updating the schema and `API.swift`

Copy the latest `schema.json` file from the `neeva` repo to `Shared/API/schema.json`

You can get the latest `schema.json` file from the monorepo:

```
cd client/packages/neeva-lib
yarn install && yarn build
```

You will then see a `gen` directory with the generated `gen/graphql/schema.json` file.

Add your query or mutation to one of the `.graphql` files in `Codegen/Sources/Codegen/` (grouped approximately by theme).
The name of the query/mutation (with `Query` or `Mutation` appended) will be used as the Swift struct name.

In Xcode, select the “Codegen” scheme and click the run button to regenerate `API.swift` with Swift bindings to the queries/mutations.

For queries, implement a `QueryController` subclass to interface with SwiftUI:

- The `Query` type is the GraphQL query type
- The `Data` type is the type you provide to your SwiftUI code. This is typically nested in the `Data` typeof the `Query` type.
  - I recommend defining a `typealias` in your subclass to make it easier for users to reference your data type
- Implement `func reload() -> Void` by calling `self.perform(query:)` with your desired query
  - To add a refresh control to a `List` or `Form`, pass your `QueryController` subclass into `List { ... }.refreshControl(refreshing:)`
- If your `Data` type is different from the `Data` type returned by the raw query, implement `class func processData(_ data: Query.Data) -> Data` to convert the raw query result to the desired type
  - If you need to access information from the query that was sent to the server, instead implement `class func processData(_ data: Query.Data, for query: Query) -> Data` which calls `processData(data)` by default.
- See `SuggestionsController` for an example of how to handle a query that responds to user input.

There is currently less infrastructure for calling mutations, but there’s a convenience API `SomeMutation().perform { result in ... }` that provides the authentication and other headers, and converts a “successful” result with errors into a failure.

### Other

For more information and resources see [this](https://paper.dropbox.com/doc/Mobile-team-overview--BVZAP5qbLb1eeOFvNqxB8jgHAg-HRB3Zxy3yWmYisYET9QvN) doc.
