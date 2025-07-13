require 'rails_helper'

RSpec.describe User, type: :model do
  subject { build(:user) }
  it { should have_many(:squaks).dependent(:destroy) }
  it { should validate_uniqueness_of(:username).case_insensitive }
end

