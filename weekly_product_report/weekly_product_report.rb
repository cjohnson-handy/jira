require 'jira'
require 'chronic'
require 'yaml'

if ARGV.length == 0
  # If not passed any command line arguments, prompt for project key.
  puts "Enter Project: "
  project = gets.strip
elsif ARGV.length == 1
  project = ARGV[0]
else
  raise "Usage: #{s0} [ project ]"
end

#
# Formats an array of Issues to be grouped by Epic.
#
def format_issue_list(issues)
  formatted = Hash.new

  issues.each do |issue|
    epic_id = issue.fields['customfield_10106']
    if formatted.has_key?(epic_id)
      formatted[epic_id][:issues].push(issue)
    else
      formatted[epic_id] = {
        id: epic_id,
        summary: "",
        issues: [issue]
      }
    end
  end

  formatted_keys = formatted.keys.reject{ |key| key.nil? || key.empty? }
  if formatted_keys.length
    fetched_epics = @client.Issue.jql("key IN(#{formatted_keys.join(',')})")
    fetched_epics.each do |epic|
      epic_key = epic.key
      formatted[epic_key][:summary] = epic.fields['summary']
    end
  end

  formatted
end

#
# Output the grouped list of Epics & Issues.
#
def output_issue_list(formatted_issues)
  formatted_issues.each do |epic_id,epic|
    puts !epic[:summary].empty? ? epic[:summary] : "Other"
    epic[:issues].each do |issue|
      puts "- #{issue.fields['summary']}"
    end
    puts ""
  end
end

config = YAML.load_file(File.join(__dir__, 'config.yml'))

options = {
  :username     => config['jira']['username'],
  :password     => config['jira']['password'],
  :site         => config['jira']['site'],
  :context_path => config['jira']['context_path'],
  :auth_type    => config['jira']['auth_type'].to_sym,
  :use_ssl      => config['jira']['use_ssl'].to_s.to_sym
}

@client = JIRA::Client.new(options)

week_start = Chronic.parse('last sunday midnight')
formatted_week_start = week_start.strftime('%F %H:%M')

last_week = @client.Issue.jql("project = '#{project}' AND type != 'Epic' AND status = 'Done' AND resolutiondate >= '#{formatted_week_start}'")
next_week = @client.Issue.jql("project = '#{project}' AND type != 'Epic' AND status NOT IN('Backlog', 'Done')")

puts "Weekly Product Report for #{project}"
puts

puts "Last Week"
output_issue_list(format_issue_list(last_week))

puts "This Week"
output_issue_list(format_issue_list(next_week))
