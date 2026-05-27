skill "devin_code" {
  description  = "Load when you use the code_develop tool in the Devin plugin"
  instructions = load("./skills/devin_code.md")
}

skill "devin_qa" {
  description  = "Load when you use the code_qa tool in the Devin plugin"
  instructions = load("./skills/devin_qa.md")
}

skill "devin_review" {
  description  = "Load when you use the code_review tool in the Devin plugin"
  instructions = load("./skills/devin_review.md")

}

skill "devin_txc_playbook" {
  description  = "Load when given a Jira ticket for a TaxCloud customer support issue. Delegates to Devin to diagnose root cause, implement a fix, create a PR, and post a structured summary back to Jira."
  instructions = load("./skills/devin_txc_support.md")
}