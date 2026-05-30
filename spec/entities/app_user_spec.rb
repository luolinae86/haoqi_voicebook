# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Entities::AppUser do
  let(:grade) { Grade.create!(name: '一年级') }
  let(:user) { AppUser.create!(grade_id: grade.id, uuid: SecureRandom.uuid, phone: '13800138000') }
  let(:user_without_grade) { AppUser.create!(uuid: SecureRandom.uuid, phone: '13800138001') }

  subject(:json) { described_class.represent(user).as_json }

  it 'exposes grade_id' do
    expect(json).to include(:grade_id)
    expect(json[:grade_id]).to eq(grade.id)
  end

  it 'exposes grade_name' do
    expect(json).to include(:grade_name)
    expect(json[:grade_name]).to eq('一年级')
  end

  it 'returns nil grade_id and grade_name when user has no grade' do
    json_without_grade = described_class.represent(user_without_grade).as_json
    expect(json_without_grade[:grade_id]).to be_nil
    expect(json_without_grade[:grade_name]).to be_nil
  end

  it 'returns nil grade_name when grade_id references a non-existent grade' do
    user.update!(grade_id: 999_999)
    json_bad = described_class.represent(user).as_json
    expect(json_bad[:grade_name]).to be_nil
  end

  it 'returns false for parental_enabled when no parental control is set' do
    expect(json[:parental_enabled]).to be false
  end

  it 'returns true for parental_enabled when parental control is active' do
    ParentalControl.create!(app_user: user, password: '1234')
    refreshed_json = described_class.represent(user.reload).as_json
    expect(refreshed_json[:parental_enabled]).to be true
  end

  it 'returns false for has_password when user has no password' do
    expect(json[:has_password]).to be false
  end

  it 'returns true for has_password when user has a password set' do
    user.update!(password: 'test1234')
    refreshed_json = described_class.represent(user.reload).as_json
    expect(refreshed_json[:has_password]).to be true
  end
end
