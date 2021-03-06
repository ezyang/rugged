# encoding: UTF-8
require File.expand_path "../test_helper", __FILE__

describe Rugged::Reference do
  UNICODE_REF_NAME = "A\314\212ngstro\314\210m"

  before do
    @path = File.dirname(__FILE__) + '/fixtures/testrepo.git'
    @repo = Rugged::Repository.new(@path)
  end

  after do
    FileUtils.remove_entry_secure(@path + '/refs/heads/unit_test', true)
    FileUtils.remove_entry_secure(@path + "/refs/heads/#{UNICODE_REF_NAME}", true)
  end

  it "can list references" do
    refs = @repo.refs.map { |r| r.name.gsub("refs/", '') }.sort.join(':')
    assert_equal "heads/master:heads/packed:tags/v0.9:tags/v1.0", refs
  end

  it "can list references with non 7-bit ASCII characters" do
    Rugged::Reference.create(@repo, "refs/heads/#{UNICODE_REF_NAME}", "refs/heads/master")
    refs = @repo.refs.map { |r| r.name.gsub("refs/", '') }.sort.join(':')
    assert_equal "heads/#{UNICODE_REF_NAME}:heads/master:heads/packed:tags/v0.9:tags/v1.0", refs
  end

  it "can list filtered references from regex" do
    refs = @repo.refs(/tags/).map { |r| r.name.gsub("refs/", '') }.sort.join(':')
    assert_equal "tags/v0.9:tags/v1.0", refs
  end

  it "can list filtered references from string" do
    refs = @repo.refs('0.9').map { |r| r.name.gsub("refs/", '') }.sort.join(':')
    assert_equal "tags/v0.9", refs
  end

  it "can open reference" do
    ref = Rugged::Reference.lookup(@repo, "refs/heads/master")
    assert_equal "36060c58702ed4c2a40832c51758d5344201d89a", ref.target
    assert_equal :direct, ref.type
    assert_equal "refs/heads/master", ref.name
  end

  it "will return nil for an invalid reference" do
    ref = Rugged::Reference.lookup(@repo, "lol/wut")
    assert_equal nil, ref
  end

  it "can get a reflog" do
    ref = Rugged::Reference.lookup(@repo, "refs/heads/master")
    log = ref.log
    e =  log[1]
    assert_equal e[:id_old], "8496071c1b46c854b31185ea97743be6a8774479"
    assert_equal e[:id_new], "5b5b025afb0b4c913b4c338a42934a3863bf3644"
    assert_equal e[:message], "commit: another commit"
    assert_equal e[:committer][:email], "schacon@gmail.com"
  end

  it "can check for the existence of a reference" do
    exists = Rugged::Reference.exist?(@repo, "refs/heads/master")
    assert exists

    exists = Rugged::Reference.exist?(@repo, "lol/wut")
    assert !exists
  end

  it "can open packed reference" do
    ref = Rugged::Reference.lookup(@repo, "refs/heads/packed")
    assert_equal "41bc8c69075bbdb46c5c6f0566cc8cc5b46e8bd9", ref.target
    assert_equal :direct, ref.type
    assert_equal "refs/heads/packed", ref.name
  end

  it "can create reference from symbolic reference" do
    ref = Rugged::Reference.create(@repo, "refs/heads/unit_test", "refs/heads/master")
    assert_equal "refs/heads/master", ref.target
    assert_equal :symbolic, ref.type
    assert_equal "refs/heads/unit_test", ref.name
    ref.delete!
  end

  it "can create reference from oid" do
    ref = Rugged::Reference.create(@repo, "refs/heads/unit_test", "36060c58702ed4c2a40832c51758d5344201d89a")
    assert_equal "36060c58702ed4c2a40832c51758d5344201d89a", ref.target
    assert_equal :direct, ref.type
    assert_equal "refs/heads/unit_test", ref.name
    ref.delete!
  end

  it "can rename ref" do
    ref = Rugged::Reference.create(@repo, "refs/heads/unit_test", "36060c58702ed4c2a40832c51758d5344201d89a")
    assert_equal "36060c58702ed4c2a40832c51758d5344201d89a", ref.target
    assert_equal :direct, ref.type
    assert_equal "refs/heads/unit_test", ref.name

    ref.rename "refs/heads/rug_new_name"
    assert_equal "refs/heads/rug_new_name", ref.name
    ref.delete!
  end

  it "can set target on reference" do
    ref = Rugged::Reference.create(@repo, "refs/heads/unit_test", "36060c58702ed4c2a40832c51758d5344201d89a")
    assert_equal "36060c58702ed4c2a40832c51758d5344201d89a", ref.target
    assert_equal :direct, ref.type
    assert_equal "refs/heads/unit_test", ref.name

    ref.target = "5b5b025afb0b4c913b4c338a42934a3863bf3644"
    assert_equal "5b5b025afb0b4c913b4c338a42934a3863bf3644", ref.target
    ref.delete!
  end

  it "can resolve head" do
    ref = Rugged::Reference.lookup(@repo, "HEAD")
    assert_equal "refs/heads/master", ref.target
    assert_equal :symbolic, ref.type

    head = ref.resolve
    assert_equal "36060c58702ed4c2a40832c51758d5344201d89a", head.target
    assert_equal :direct, head.type
  end


  describe "reference target" do
    before do
      @path = temp_repo 'testrepo.git'
      @repo = Rugged::Repository.new(@path)
    end

    after do
      destroy_temp_repo(@path)
    end

    it "returns the reference target name with UTF-8 encoding" do
      Rugged::Reference.create(@repo, "refs/heads/Ångström", "refs/heads/master")

      ref = Rugged::Reference.create(@repo, "refs/heads/foobar", "refs/heads/Ångström")
      assert_equal "refs/heads/Ångström", ref.target
    end
  end

  describe "reference logging" do
    before do
      @path = temp_repo 'testrepo.git'
      @repo = Rugged::Repository.new(@path)

      @ref = Rugged::Reference.create(@repo, "refs/heads/test-reflog", "36060c58702ed4c2a40832c51758d5344201d89a")
    end

    after do
      destroy_temp_repo(@path)
    end

    it "creates reflog entries" do
      @ref.log!({ :name => "foo", :email => "foo@bar", :time => Time.now })
      @ref.log!({ :name => "foo", :email => "foo@bar", :time => Time.now }, "commit: bla bla")

      reflog = @ref.log
      assert_equal reflog.size, 2

      assert_equal reflog[0][:id_old], "0000000000000000000000000000000000000000"
      assert_equal reflog[0][:id_new], "36060c58702ed4c2a40832c51758d5344201d89a"
      assert_equal reflog[0][:message], nil
      assert_equal reflog[0][:committer][:name], "foo"
      assert_equal reflog[0][:committer][:email], "foo@bar"
      assert_kind_of Time, reflog[0][:committer][:time]

      assert_equal reflog[1][:id_old], "36060c58702ed4c2a40832c51758d5344201d89a"
      assert_equal reflog[1][:id_new], "36060c58702ed4c2a40832c51758d5344201d89a"
      assert_equal reflog[1][:message], "commit: bla bla"
      assert_equal reflog[1][:committer][:name], "foo"
      assert_equal reflog[1][:committer][:email], "foo@bar"
      assert_kind_of Time, reflog[1][:committer][:time]

    end
  end

  describe "reference name" do
    before do
      @path = temp_repo 'testrepo.git'
      @repo = Rugged::Repository.new(@path)
    end

    after do
      destroy_temp_repo(@path)
    end

    it "returns the reference name with UTF-8 encoding" do
      ref = Rugged::Reference.create(@repo, "refs/heads/Ångström", "refs/heads/master")
      assert_equal "refs/heads/Ångström", ref.name
    end
  end
end

