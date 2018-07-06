require "rails_helper"

describe Results::WebResponseParser do
  include_context "response tree"

  context "simple form" do
    # form item ids have to actually exist
    let(:form) { create(:form, question_types: %w[text text text]) }

    it "builds matching tree" do
      input = ActionController::Parameters.new({
        root: {
          id: "",
          type: "AnswerGroup",
          questioning_id: form.root_group.id,
          relevant: "true",
          children: {
            "0" => {
              id: "",
              type: "Answer",
              questioning_id: form.c[0].id,
              relevant: "true",
              value: "A"
            },
            "1" => {
              id: "",
              type: "Answer",
              questioning_id: form.c[1].id,
              relevant: "true",
              value: "B"
            },
            "2" => {
              id: "",
              type: "Answer",
              questioning_id: form.c[2].id,
              relevant: "true",
              value: "C"
            }
          }
        }
      })
      tree = Results::WebResponseParser.new.parse(input)
      expect_root(tree, form)
      expect_children(tree, %w[Answer Answer Answer], form.c.map(&:id), %w[A B C])
    end

    context "forms with a group" do
      let(:form) { create(:form, question_types: ["text", %w[text text], "text"]) }

      it "should produce the correct tree" do
        input = ActionController::Parameters.new({
          root: {
            id: "",
            type: "AnswerGroup",
            questioning_id: form.root_group.id,
            relevant: "true",
            children: {
              "0" => {
                id: "",
                type: "Answer",
                questioning_id: form.c[0].id,
                relevant: "true",
                value: "A"
              },
              "1" => {
                id: "",
                type: "AnswerGroup",
                questioning_id: form.c[1].id,
                relevant: "true",
                children:  {
                  "0" => {
                    id: "",
                    type: "Answer",
                    questioning_id: form.c[1].c[0].id,
                    relevant: "true",
                    value: "B"
                  },
                  "1" => {
                    id: "",
                    type: "Answer",
                    questioning_id: form.c[1].c[1].id,
                    relevant: "true",
                    value: "C"
                  }
                }
              },
              "2" => {
                id: "",
                type: "Answer",
                questioning_id: form.c[2].id,
                relevant: "true",
                value: "D"
              }
            }
          }
        })
        tree = Results::WebResponseParser.new.parse(input)
        expect_root(tree, form)
        expect_children(tree, %w[Answer AnswerGroup Answer], form.c.map(&:id), ["A", nil, "D"])
        expect_children(tree.c[1], %w[Answer Answer], form.c[1].c.map(&:id), %w[B C])
      end
    end
  end
end
