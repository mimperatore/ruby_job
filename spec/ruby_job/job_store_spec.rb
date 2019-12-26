# frozen_string_literal: true

module RubyJob
  RSpec.describe JobStore do
    describe '#enqueue' do
      it 'raises NotImplementedError' do
        expect { subject.enqueue(nil) }.to raise_error(NotImplementedError)
      end
    end

    describe '#dequeue' do
      it 'raises NotImplementedError' do
        expect { subject.dequeue(nil) }.to raise_error(NotImplementedError)
      end
    end

    describe '#fetch' do
      it 'raises NotImplementedError' do
        expect { subject.fetch }.to raise_error(NotImplementedError)
      end
    end
  end
end
