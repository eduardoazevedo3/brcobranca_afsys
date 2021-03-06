# -*- encoding: utf-8 -*-
#
# A Caixa tem dois padrões para a geração de boleto: SIGCB e SICOB.
# O SICOB foi substiuido pelo SIGCB que é implementado por esta classe.
# http://downloads.caixa.gov.br/_arquivos/cobranca_caixa_sigcb/manuais/CODIGO_BARRAS_SIGCB.PDF
#
module Brcobranca
  module Boleto
    class GuiaSindicalCaixa < Base # Caixa
      # <b>REQUERIDO</b>: Emissão do boleto
      attr_accessor :emissao
      attr_accessor :prefixo
      attr_accessor :tipo_entidade
      attr_accessor :codigo_sindical
      attr_accessor :codigo_central_sindical
      attr_accessor :codigo_confederacao
      attr_accessor :codigo_federacao
      attr_accessor :codigo_atividade
      attr_accessor :competencia
      attr_accessor :cedente_logradouro
      attr_accessor :cedente_numero
      attr_accessor :cedente_complemento
      attr_accessor :cedente_cep
      attr_accessor :cedente_bairro
      attr_accessor :cedente_cidade
      attr_accessor :cedente_uf
      attr_accessor :sacado_logradouro
      attr_accessor :sacado_numero
      attr_accessor :sacado_complemento
      attr_accessor :sacado_cep
      attr_accessor :sacado_bairro
      attr_accessor :sacado_cidade
      attr_accessor :sacado_uf
      attr_accessor :categoria
      attr_accessor :capital_social_empresa
      attr_accessor :numero_empregado_contribuinte
      attr_accessor :capital_social_estabelecimento
      attr_accessor :total_remuneracao_contribuinte
      attr_accessor :total_empregado_estabelecimento

      # Validações
      # Modalidade/Carteira de Cobrança (1-Registrada | 2-Sem Registro)
      validates_length_of :carteira, is: 1, message: 'deve possuir 1 dígito.'
      # Tipo de entidade (1-Sindicato | 2-Federação | 3-Confederação | 4-Cees)
      validates_length_of :tipo_entidade, is: 1, message: 'deve possuir 1 dígito.'
      # Emissão do boleto (4-Beneficiário)
      validates_length_of :codigo_atividade, is: 3, message: 'deve possuir 3 dígitos.'
      validates_length_of :categoria, is: 1, message: 'deve possuir 1 dígito.'
      validates_length_of :emissao, is: 1, message: 'deve possuir 1 dígitos.'
      validates_length_of :prefixo, is: 2, message: 'deve possuir 2 dígitos.'
      validates_length_of :convenio, is: 6, message: 'deve possuir 6 dígitos.'
      validates_length_of :numero_documento, is: 13, message: 'deve possuir 15 dígitos.'

      # Nova instância da CaixaEconomica
      # @param (see Brcobranca::Boleto::Base#initialize)
      def initialize(campos = {})
        campos = {
          carteira: '1',
          emissao: '4',
          prefixo: '00'
        }.merge!(campos)

        campos.merge!(local_pagamento: 'PREFERENCIALMENTE NAS CASAS LOTÉRICAS ATÉ O VALOR LIMITE')

        super(campos)
      end

      # Código do banco emissor
      # @return [String]
      def banco
        '104'
      end

      # Dígito verificador do código do banco em módulo 10
      # Módulo 10 de 104 é 0
      # @return [String]
      def banco_dv
        '0'
      end

      # Número do convênio/contrato do cliente junto ao banco.
      # @return [String] 6 caracteres numéricos.
      def convenio=(valor)
        @convenio = valor.to_s.rjust(6, '0') if valor
      end

      # Número seqüencial utilizado para identificar o boleto.
      # @return [String] 15 caracteres numéricos.
      def numero_documento=(valor)
        @numero_documento = valor.to_s.rjust(13, '0') if valor
      end

      # Nosso número, 17 dígitos
      # @return [String]
      def nosso_numero_boleto
        "#{nosso_numero}-#{nosso_numero_dv}"
      end

      # Nosso número, 17 dígitos
      #  1 à 2: carteira
      #  3 à 4: prefixo
      #  5 à 17: campo_livre
      def nosso_numero
        "#{carteira}#{emissao}#{prefixo}#{numero_documento}"
      end

      # Dígito verificador do Nosso Número
      # Utiliza-se o [-1..-1] para retornar o último caracter
      # @return [String]
      def nosso_numero_dv
        nosso_numero.modulo11(
          multiplicador: (2..9).to_a,
          mapeamento: { 10 => 0, 11 => 0 }
        ) { |total| 11 - (total % 11) }.to_s
      end

      # Número da agência/código cedente do cliente para exibir no boleto.
      # @return [String]
      # @example
      #  boleto.agencia_conta_boleto #=> "1565/100000-4"
      def agencia_conta_boleto
        "#{agencia}/#{codigo_central_sindical || '000'}.#{codigo_confederacao || '000'}.#{codigo_federacao || '000'}.#{codigo_sindical || '00000-0'}"
      end

      # Dígito verificador do convênio ou código do cedente
      # @return [String]
      def convenio_dv
        convenio.modulo11(
          multiplicador: (2..9).to_a,
          mapeamento: { 10 => 0, 11 => 0 }
        ) { |total| 11 - (total % 11) }.to_s
      end

      # Logotipo do banco
      # @return [Path] Caminho para o arquivo de logotipo do banco.
      def logotipo
        File.join(File.dirname(__FILE__), '..', 'arquivos', 'logos', 'caixa.eps')
      end

      # Monta a segunda parte do código de barras.
      #  1 à 6: código do cedente, também conhecido como convênio
      #  7: dígito verificador do código do cedente
      #  8 à 10: dígito 3 à 5 do nosso número
      #  11: dígito 1 do nosso número (modalidade da cobrança)
      #  12 à 14: dígito 6 à 8 do nosso número
      #  15: dígito 2 do nosso número (emissão do boleto)
      #  16 à 24: dígito 9 à 17 do nosso número
      #  25: dígito verificador do campo livre
      # @return [String]
      def codigo_barras_segunda_parte
        campo_livre = "#{convenio}" \
        "#{convenio_dv}" \
        "#{nosso_numero[2..4]}" \
        "#{nosso_numero[0..0]}" \
        "#{nosso_numero[5..7]}" \
        "#{nosso_numero[1..1]}" \
        "#{nosso_numero[8..16]}"

        "#{campo_livre}" +
          campo_livre.modulo11(
            multiplicador: (2..9).to_a,
            mapeamento: { 10 => 0, 11 => 0 }
          ) { |total| 11 - (total % 11) }.to_s
      end
    end
  end
end
