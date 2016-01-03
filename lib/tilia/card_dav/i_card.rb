module Tilia
  module CardDav
    # Card interface
    #
    # Extend the ICard interface to allow your custom nodes to be picked up as
    # 'Cards'.
    module ICard
      include Dav::IFile
    end
  end
end
