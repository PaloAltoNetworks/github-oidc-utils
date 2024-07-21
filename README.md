![image](https://github.com/user-attachments/assets/49385333-71b8-421b-935b-d8ee071c3928)

# GitHub OIDC Utils 🛠️

Hi there OIDC nerds 👋🐋 Hope you will find this repo valuable

This repo accompanies my talk from DC32 regarding OIDC abuses - ["OH-MY-DC"](https://replace-me.com).

It includes a look into GitHub OIDC claims in security context(not a "how to configure OIDC" guide), as well as a tool to modify and assess the `sub` claim format of an organization or repository.

### [➡ For the GitHub OIDC utils tool, click here 🛠️](./oidc-utils/)

---

## GitHub OIDC claims dive 🏊‍♂

GitHub OIDC claims(=> simply put - the json keys in the token) are the claims that are returned in the ID Token when you authenticate with GitHub. These claims are used to identify the user and to provide information about the user for a later token consumer.

In the context of a CI machine (GitHub Actions), it contains the pipeline's contextual information, which includes the repository, branch, commit, workflow, run number, actor, environment, etc.

[According to GitHub](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect#understanding-the-oidc-token), the returned claims in the ID Token are:

```yaml
jti: example-id # Unique identifier for the token, used for preventing replay attacks
sub: repo:octo-org/octo-repo:environment:prod # Defines the subject claim that is to be validated by the cloud provider, essential for predictable access token allocation
environment: prod # The name of the environment used by the job
environment_node_id: example-node-id # The unique identifier of the environment node
enterprise: octo-org # The name of the enterprise account
enterprise_id: "1" # The ID of the enterprise account
aud: https://github.com/octo-org # Audience claim, typically the URL of the repository owner
ref: refs/heads/main # The Git reference (branch or tag) that triggered the workflow
sha: example-sha # The commit SHA that triggered the workflow
repository: octo-org/octo-repo # The full name of the repository
repository_owner: octo-org # The owner of the repository
actor_id: "12" # The ID of the personal account that initiated the workflow run
repository_visibility: private # The visibility of the repository (internal, private, or public)
repository_id: "74" # The ID of the repository
repository_owner_id: "65" # The ID of the organization in which the repository is stored
run_id: example-run-id # The ID of the workflow run that triggered the workflow
run_number: "10" # The number of times this workflow has been run
run_attempt: "2" # The number of times this workflow run has been retried
runner_environment: github-hosted # The type of runner used by the job (github-hosted or self-hosted)
actor: octocat # The personal account that initiated the workflow run
workflow: example-workflow # The name of the workflow
head_ref: branch_name # The source branch of the pull request in a workflow run
base_ref: branch_name # The target branch of the pull request in a workflow run
event_name: workflow_dispatch # The name of the event that triggered the workflow run
ref_type: branch # The type of ref (branch or tag)
job_workflow_ref: octo-org/octo-automation/.github/workflows/oidc.yml@refs/heads/main # The ref path to the reusable workflow
workflow_ref: octocat/hello-world/.github/workflows/my-workflow.yml@refs/heads/my_branch # The ref path to the workflow
workflow_sha: example-sha # The commit SHA for the workflow file
iss: https://token.actions.githubusercontent.com # Issuer of the token, which is GitHub's OIDC provider
nbf: 1632492967 # Not Before time, a timestamp indicating when the token becomes valid
exp: 1632493867 # Expiry time, a timestamp indicating when the token expires
iat: 1632493567 # Issued At time, a timestamp indicating when the token was issued
job_workflow_sha: example-sha # The commit SHA for the reusable workflow file
context: prod # The context of the workflow run, typically the environment name or ref -- NOT AN ACTUAL JSON KEY!
ref_protected: false # Indicates whether the ref is protected
```

That is a total of 34 claims.

### GitHub OIDC claims security considerations 🛡️

Below there's a list of all the claims that are derived from the user. For each one there's an explanation whether a claim could be trusted-upon solely or whether should it be allowed to be the prefix of the `sub` claim.

For where claims are stated as "unsafe", this does not mean they shouldn't be used, but it **DOES** mean they **shouldn't be used solely during asserting or prefix the `sub` claim format**.

First, the following claims (5/34) are useless for our case as they are not derived from any user input:

- `jti`
- `iss`
- `nbf`
- `exp` - The only thing to note here is that the token expires 4 minutes after being issued (pr if the time is different now)
- `iat`

This leaves us with the following claims to consider (ignoring the `sub` of-course):

| #   | Claim Name              | Safe to be asserted solely | Safe as a prefix for custom `sub` formats                                | Comment                                                                                                                                                                                                                               |
| --- | ----------------------- | -------------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `repository`            | ✅                          | ✅                                                                        | org/user name is unique by GitHub                                                                                                                                                                                                     |
| 2   | `repository_owner`      | ✅                          | ✅                                                                        | org/user name is unique by GitHub                                                                                                                                                                                                     |
| 3   | `actor`                 | ✅                          | ✅                                                                        | org/user name is unique by GitHub                                                                                                                                                                                                     |
| 4   | `aud`                   | ✅                          | ⛔️ will cause GHA to not run if set as a part of the `sub` format         | typically the URL of the repository owner, but can be changed with ease                                                                                                                                                               |
| 5   | `sha`                   | ✅                          | ⛔️ can not be used for `sub` format                                       | The commit SHA that triggered the workflow                                                                                                                                                                                            |
| 6   | `workflow_ref`          | ✅                          | ✅                                                                        | The ref path to the workflow                                                                                                                                                                                                          |
| 7   | `workflow_sha`          | ✅                          | ✅                                                                        | The commit SHA for the workflow file                                                                                                                                                                                                  |
| 8   | `job_workflow_ref`      | ✅                          | ✅                                                                        | Includes the full path which contains the repo name and is unique by GitHub                                                                                                                                                           |
| 9   | `job_workflow_sha`      | ✅                          | ✅                                                                        | The commit SHA for the reusable workflow file                                                                                                                                                                                         |
| 10  | `runner_environment`    | ✅                          | ✅                                                                        | The type of runner used by the job (github-hosted or self-hosted)                                                                                                                                                                     |
| 11  | `enterprise_id`         | ✅                          | ⛔️ can not be used for `sub` format                                       | The ID of the enterprise is unique by GitHub                                                                                                                                                                                          |
| 12  | `enterprise`            | ✅                          | ⛔️ can not be used for `sub` format                                       | The name of the enterprise is unique by GitHub                                                                                                                                                                                        |
| 13  | `repository_id`         | ✅📡                         | ✅                                                                        | Unique value that requires the API in order to get the ID                                                                                                                                                                             |
| 14  | `repository_owner_id`   | ✅📡                         | ✅                                                                        | Unique value that requires the API in order to get the ID                                                                                                                                                                             |
| 15  | `actor_id`              | ✅📡                         | ✅                                                                        | Unique value that requires the API in order to get the ID                                                                                                                                                                             |
| 16  | `run_id`                | ✅👎                         | ✅                                                                        | Unique value but is unpredictable                                                                                                                                                                                                     |
| 17  | `run_number`            | ✅👎                         | ✅                                                                        | Unique value but is unpredictable                                                                                                                                                                                                     |
| 18  | `environment_node_id`   | ✅👎                         | ✅                                                                        | Unique value but is unpredictable. If used as a part of `sub` format, will fail the action if there's no environment declared                                                                                                         |
| 19  | `workflow`              | ❌                          | ❌                                                                        | The workflow name which is reproducible; Could also be used to abuse `sub` suffixes if used as their prefix                                                                                                                           |
| 20  | `run_attempt`           | ❌                          | ✅                                                                        | A `run_attempt:n` claim, where `n` is an incrementing number                                                                                                                                                                          |
| 21  | `ref`                   | ❌                          | ✅❌ (see comment)                                                         | Will be `ref/heads/main` or `ref/tags/<tag>` and is reproducible; Could be used to abuse `sub` suffixed in some cases (limited by `git` branch and tag naming restrictions)                                                           |
| 22  | `event_name`            | ❌                          | ✅                                                                        | Will be the event name, like "push", and is reproducible                                                                                                                                                                              |
| 23  | `ref_type`              | ❌                          | ✅                                                                        | Will be "branch" or "tag", and is reproducible                                                                                                                                                                                        |
| 24  | `repository_visibility` | ❌                          | ✅                                                                        | Will be "public" or "private", and is reproducible                                                                                                                                                                                    |
| 25  | `context`               | ❌                          | ✅❌ (if `environment` is set then like `environment`, else -> like `ref`) | Used in the `sub` by default - if `environment` is set for the workflow, it will be the content of the `environment` claim, if not, it will be `ref` claim; This is a pseudo-claim that gets replaced according to the incoming event |
| 26  | `head_ref`              | ❌ - PR specific            | ✅❌ (like `ref`)                                                          | if not in PR, will echo `head_ref`, if in PR, will be the PR branch name, which is reproducible                                                                                                                                       |
| 27  | `base_ref`              | ❌ - PR specific            | ✅❌ (like `ref`)                                                          | if not in PR, will echo `base_ref`, if in PR, will be the base branch name, which is reproducible                                                                                                                                     |
| 28  | `environment`           | ❌                          | ❌                                                                        | A reproducible string. Will fail the action if there's no environment declared and is set as a prt of the `sub` format                                                                                                                |
| 29  | `ref_protected`         | ❌                          | ⛔️ can not be used for `sub` format                                       | will be "false" or "true", indicating if the ref is protected or not                                                                                                                                                                  |

To conclude, if you'd assert the claim `workflow` or `run_attempt` solely, you'd be in a bad spot. If you'd use them as a prefix for the `sub` claim format, you'd be in a bad spot as well.

On the contrary, prefixing the `sub` claim format with `repository` and similar other claims is safe.

### 🏴‍☠️ Danger 🏴‍☠️

Do note, that regardless of the above, lax assertions (i.e. `myorg/*/environment:123`) could still lead to compromises, as upon an [IPPE](https://www.paloaltonetworks.com/cyberpedia/poisoned-pipeline-execution-cicd-sec4) one could still access the configured identity.

Watch my talk for a demo 😉
