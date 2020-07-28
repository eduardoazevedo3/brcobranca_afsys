# -*- encoding: utf-8 -*-

module Brcobranca
  module Boleto
    module Template
      module Base
        extend self

        def define_template(template)
          case template
          when :rghost
            return [Brcobranca::Boleto::Template::Rghost]
          when :rghost_guia_sindical
            return [Brcobranca::Boleto::Template::RghostGuiaSindical]
          when :rghost_carne
            return [Brcobranca::Boleto::Template::RghostCarne]
          when :rghost_e_guia_sindical
            return [Brcobranca::Boleto::Template::Rghost, Brcobranca::Boleto::Template::RghostGuiaSindical]
          when :both
            return [Brcobranca::Boleto::Template::Rghost, Brcobranca::Boleto::Template::RghostCarne, Brcobranca::Boleto::Template::RghostGuiaSindical]
          else
            return [Brcobranca::Boleto::Template::Rghost]
          end
        end
      end
    end
  end
end
