require "rubygems"
require "bundler/setup"

require 'grit'
require 'github_api'

class GithubHelper
	def self.push_commits(github, username, reponame, git_path, oldsha, newsha, ref)
		grit_repo = Grit::Repo.new(git_path)

		commits = grit_repo.commits_between(oldsha, newsha)
		commits.each do |cobj|
			push_tree(github, username, reponame, cobj.tree)
			push_commit(github, username, reponame, cobj)
		end
	end

	def self.update_ref(github, username, reponame, ref, sha, force=false)
		if ref.start_with?("refs/")
			ref = ref[5..-1]
		end

		github.git_data.references.update(username, reponame, ref,
			"sha" => sha,
			"force" => force)
	end

	def self.create_ref(github, username, reponame, ref, sha)
		unless ref.start_with?("refs/")
			ref = "refs/#{ref}"
		end

		github.git_data.references.create(username, reponame, ref, "sha" => sha)
	end

	def self.remove_ref(github, username, reponame, ref)
		if ref.start_with?("refs/")
			ref = ref[5..-1]
		end

		github.git_data.references.remove(username, reponame, ref)
	end

	private
	def self.push_tree(github, username, reponame, grit_tree)
		entries = []

		# Process sub-trees and collect shas
		grit_tree.trees.each do |tobj|
			tsha = self.push_tree(github, username, reponame, tobj)
			entries << {
						 "path" => tobj.name,
						 "mode" => "040000", 
						 "type" => "tree", 
						 "sha" => tsha
						}
		end

		# Collect blobs
		grit_tree.blobs.each do |bobj|
			entries << {
						 "path" => bobj.name,
						 "mode" => "100644",
						 "type" => "blob",
						 "content" => bobj.data
						}
		end
		# push with sub-trees and blobs shas
		result = github.git_data.trees.create(username, reponame, "tree" => entries)
		result[:sha]
	end

	def self.push_commit(github, username, reponame, grit_commit)
		result = github.git_data.commits.create(username, reponame,
			"message" => grit_commit.message,
			"author" => {
				"name" => grit_commit.author.name,
				"email" => grit_commit.author.email,
				"date" => grit_commit.date
				},
			"parents" => grit_commit.parents.map { |parent| parent.sha },
			"tree" => grit_commit.tree.sha)

		result[:sha]
	end

	def self.push_ref(github, username, reponame, ref, grit_commit)

	end

end
