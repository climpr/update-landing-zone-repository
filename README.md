# Update Landing Zone Repository

<!-- TOC -->

- [Update Landing Zone Repository](#update-landing-zone-repository)
  - [How to use this action](#how-to-use-this-action)
  - [Prerequisites](#prerequisites)
    - [`repoSource` strategy (Preferred)](#reposource-strategy-preferred)
    - [`repoTemplate` strategy](#repotemplate-strategy)
  - [delete-files.json](#delete-filesjson)
    - [File schema](#file-schema)
    - [Generating file hashes](#generating-file-hashes)
      - [Example](#example)
  - [Parameters](#parameters)
    - [`landing-zone-path`](#landing-zone-path)
    - [`repo-sources-path`](#repo-sources-path)
    - [`github-token`](#github-token)
  - [Outputs](#outputs)
    - [`deleted-files`](#deleted-files)
    - [`deleted-directories`](#deleted-directories)

<!-- /TOC -->

This action updates files in Landing Zone Repositories.

It can be used with two strategies:

1. `repoSources` (Preferred) source directories.
2. `repoTemplate` GitHub template repository.

It will sync all files in the respective source to the target Landing Zone repository.
In addition, it will delete any files located in an `delete-files.json` file containing file paths and file hashes.

## How to use this action

To use this action, implement the steps as shown below in your workflow.

```yaml
# ...
permissions: read

steps:
  - name: Checkout repository
    uses: actions/checkout@v4

  - name: Get GH Token
    id: gh-app-token
    uses: actions/create-github-app-token@v1
    with:
      app-id: ${{ vars.GH_APP_ID }}
      private-key: ${{ secrets.GH_APP_PRIVATE_KEY }}
      owner: ${{ github.repository_owner }}

  - name: Update Landing Zone Repository
    uses: climpr/update-landing-zone-repository@v1
    with:
      landing-zone-path: ${{ path-to-landing-zone-dir }}
      repo-sources-path: lz-management/repo-sources
      github-token: ${{ steps.gh-app-token.outputs.token }}
# ...
```

## Prerequisites

- If the Landing Zone is configured to use the `repoSource` strategy, it requires the repository to be checked out first.
- A GitHub token that has `Read and write` permissions `Contents` on the target Landing Zone repository.
- A `delete-files.json` configuration file for specifying which files to delete. More on this file in a separate chapter.

The target Landing Zone can be configured with either of the two strategies. The prerequisites for the strategies are as follows:

### `repoSource` strategy (Preferred)

- A `repo-sources` directory in the repository running this action.
- A `source` subdirectory in the `repo-sources` directory corresponding to the `repoSources.source` property in the Landing Zone configuration file.
- The named `source` directory must contain a `contents` subdirectory containing the source files to copy.
- The named `source` directory must contain a `delete-files.json` file, specifying which files to delete. More on this file in a separate chapter.

> [!TIP]
> The `repo-sources` directory can contain multiple `source` subdirectories to support different repositories having different sources or versioning sources.

The file structure must be as follows:

```
../
  repo-sources/
    <source>/
      delete-files.json
      contents/
        ...<source files>
        ...<source files>
    <source2>/
      delete-files.json
      contents/
        ...
```

### `repoTemplate` strategy

As opposed to the `repoSource` strategy, the `repoTemplate`

- A GitHub repository corresponding to the `repoTemplate` property in the Landing Zone configuration file.
- The GitHub template repository must be configured as a template repository in GitHub.
- The GitHub repository must contain the source files for the update operation.
- The GitHub repository must contain a `delete-files.json` file in the root directory.

The file structure must be as follows:

```
<Repository>/
  delete-files.json
  ...<source files>
  ...<source files>
```

## delete-files.json

This action requires you to create a `delete-files.json` configuration file.
As the target repositories will contain files that are not part of the source directories or repositories, we cannot know which files to delete without explicitly configuring them.
The `delete-files.json` file is used to specify which files to delete and which files to skip.

To create this file, start with an empty file and add the following content:

```json
{
  "$schema": "https://raw.githubusercontent.com/climpr/climpr-schemas/main/schemas/v1.0.0/lz-management/delete-files.json#"
}
```

This will ensure you have auto-complete and validation for the configuration file.

### File schema

An example file looks like this:

> [!TIP]
> You can use either the `hash` property for a single file hash, or `hashes` property for a list of file hashes. This can be useful if you want to support multiple versions of the same file.

```jsonc
{
  "$schema": "https://raw.githubusercontent.com/climpr/climpr-schemas/main/schemas/v1.0.0/lz-management/delete-files.json#",
  // A list of directory relative paths that should be excluded from processing.
  "directoriesToExclude": [
    ".git" // The '.git', 'delete-files.json' and 'delete-files.jsonc' directory and files are always excluded.
  ],
  // A list of directory relative paths that should be deleted.
  "filesToDelete": [
    {
      "path": "string", // Relative path to file
      "hash": "3A888546831AE05A0EC1D040DE396262284E4B4FC0066A00D56016BF3955C90E" // File hash
    },
    {
      "path": "string", // Relative path to file
      "hashes": [
        // List of file hashes
        "3A888546831AE05A0EC1D040DE396262284E4B4FC0066A00D56016BF3955C90E"
      ]
    }
  ]
}
```

### Generating file hashes

Generating file hashes is done by using the `Get-FileHash` command in PowerShell.

#### Example

In this example, the file hash is the string under `Hash` below.

```powershell
Get-FileHash "./directory/file.txt"

# Result
# Algorithm       Hash                                                                   Path
# ---------       ----                                                                   ----
# SHA256          E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855       <root-path>/directory/file.txt
```

## Parameters

### `landing-zone-path`

(Required) Path to the Landing Zone directory.

### `repo-sources-path`

(Required) Path to the 'repo-sources' directory.

### `github-token`

(Required) The token for the GitHub app that is allowed to create and update repositories in the organization.

## Outputs

### `deleted-files`

A JSON list of the deleted files relative to the 'path' input parameter.

### `deleted-directories`

A JSON list of the deleted directories relative to the 'path' input parameter.
