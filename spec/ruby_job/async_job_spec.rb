# frozen_string_literal: true

module RubyJob
  RSpec.describe Job do
    before(:each) do
      Timecop.freeze(Time.now)
    end

    let(:class_name) { 'c' }
    let(:args) { [1] }
    let(:start_at) { Time.now }
    let(:expected_hash) do
      {
        'json_class' => described_class.name,
        'data' => {
          'class_name' => class_name,
          'args_json' => JSON.dump(args),
          'start_at' => start_at.iso8601(9)
        }
      }
    end

    subject { described_class.new(class_name: class_name, args: args, start_at: start_at) }

    describe '#==' do
      context 'equality' do
        it 'compares equal objects correctly' do
          other = described_class.new(class_name: class_name, args: args, start_at: start_at)
          expect(subject).to eq(other)
        end

        it 'compares equal objects correctly when args are nil' do
          obj1 = described_class.new(class_name: class_name, args: nil, start_at: start_at)
          obj2 = described_class.new(class_name: class_name, args: nil, start_at: start_at)
          expect(obj1).to eq(obj2)
        end
      end

      context 'inequality' do
        it 'compares non-equal objects correctly (different class_name)' do
          other = described_class.new(class_name: 'd', args: args, start_at: start_at)
          expect(subject).not_to eq(other)
        end

        it 'compares non-equal objects correctly (different args)' do
          other = described_class.new(class_name: class_name, args: [2], start_at: start_at)
          expect(subject).not_to eq(other)
        end

        it 'compares non-equal objects correctly (one nil arg)' do
          other = described_class.new(class_name: class_name, args: nil, start_at: start_at)
          expect(subject).not_to eq(other)
        end

        it 'compares non-equal objects correctly (different start_at)' do
          other = described_class.new(class_name: class_name, args: args, start_at: start_at + 1)
          expect(subject).not_to eq(other)
        end
      end
    end

    describe '#to_h' do
      it 'returns a hash representation of the object' do
        expect(subject.to_h).to eq(expected_hash)
      end
    end

    describe '#to_json' do
      it 'returns the json encoding of #to_h, with the specified options' do
        options = double('options')
        hash = double('hash')
        json = double('json')
        expect(subject).to receive(:to_h).and_return(hash)
        expect(hash).to receive(:to_json).with(options).and_return(json)
        expect(subject.to_json(options)).to eq(json)
      end
    end

    describe '.json_create' do
      it 'returns a Job from the specified hash' do
        expect(Job.json_create(JSON.parse(subject.to_json))).to eq(subject)
      end
    end
  end
end
