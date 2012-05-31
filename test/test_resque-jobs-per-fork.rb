require 'test_helper'

class SomeJob
  def self.perform(i)
    $SEQUENCE << "work_#{i}".to_sym
  end
end

Resque.before_perform_jobs_per_fork do |worker|
  $SEQUENCE << :before_perform_jobs_per_fork
end

Resque.after_perform_jobs_per_fork do |worker|
  $SEQUENCE << :after_perform_jobs_per_fork
end

class TestResqueMultiJobFork < Test::Unit::TestCase
  def setup
    $SEQUENCE = []

    Resque.remove_queue(:jobs)

    ENV['JOBS_PER_FORK'] = '2'
    @worker = Resque::Worker.new(:jobs)
    @worker.cant_fork = true
  end

  def test_one_job
    Resque::Job.create(:jobs, SomeJob, 1)
    @worker.work(0)

    assert_equal([:before_perform_jobs_per_fork, :work_1, :after_perform_jobs_per_fork], $SEQUENCE)
  end

  def test_two_jobs
    Resque::Job.create(:jobs, SomeJob, 1)
    Resque::Job.create(:jobs, SomeJob, 2)
    @worker.work(0)
    assert_equal([:before_perform_jobs_per_fork, :work_1, :work_2, :after_perform_jobs_per_fork], $SEQUENCE)
  end

  def test_three_jobs
    Resque::Job.create(:jobs, SomeJob, 1)
    Resque::Job.create(:jobs, SomeJob, 2)
    Resque::Job.create(:jobs, SomeJob, 3)
    @worker.work(0)

    assert_equal([
       :before_perform_jobs_per_fork, :work_1, :work_2, :after_perform_jobs_per_fork,
       :before_perform_jobs_per_fork, :work_3, :after_perform_jobs_per_fork
    ], $SEQUENCE)
  end

  def test_default_jobs_per_fork
    ENV.delete('JOBS_PER_FORK')
    Resque::Job.create(:jobs, SomeJob, 1)
    Resque::Job.create(:jobs, SomeJob, 2)
    @worker.work(0)

    assert_equal([
       :before_perform_jobs_per_fork, :work_1, :after_perform_jobs_per_fork,
       :before_perform_jobs_per_fork, :work_2, :after_perform_jobs_per_fork
    ], $SEQUENCE)
  end

  def test_work_normally_if_env_var_set
    assert_nothing_raised(RuntimeError) do
      Resque::Job.create(:jobs, SomeJob, 1)
      @worker.work(0)
    end
  end

  def test_no_crash_if_no_env_var_set
    ENV.delete('JOBS_PER_FORK')

    assert_nothing_raised(RuntimeError) do
      Resque::Job.create(:jobs, SomeJob, 1)
      @worker.work(0)
    end
  end
end
