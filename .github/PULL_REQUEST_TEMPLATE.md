## Prompt Deployment

### Description
<!-- Briefly describe the prompts being added or modified -->

### Prompt Files Added/Modified
<!-- List the prompt configuration files -->
- [ ] `prompts/`

### Template Files Added/Modified
<!-- List the template files -->
- [ ] `prompt_templates/`

### Testing
- [ ] Tested locally with `process_prompt.py`
- [ ] Verified template variables are correct
- [ ] Reviewed Bedrock model selection
- [ ] Checked output format (html/md)

### Deployment
- [ ] Ready for beta deployment
- [ ] Will review beta outputs before merging to prod

### Notes
<!-- Any additional context or special instructions -->

---

**Beta Deployment:** When this PR is created, the workflow will automatically process prompts and upload to the beta S3 bucket (`beta/` prefix).

**Production Deployment:** Merging this PR will deploy to the production S3 bucket (`prod/` prefix).
