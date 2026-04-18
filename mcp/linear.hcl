mcp "linear" {
  url = "https://mcp.linear.app/mcp"
  headers = {
    Authorization = "Bearer ${vars.linear_token}"
  }
}