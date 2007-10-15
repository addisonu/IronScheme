/* ****************************************************************************
 *
 * Copyright (c) Microsoft Corporation. 
 *
 * This source code is subject to terms and conditions of the Microsoft Permissive License. A 
 * copy of the license can be found in the License.html file at the root of this distribution. If 
 * you cannot locate the  Microsoft Permissive License, please send an email to 
 * dlr@microsoft.com. By using this source code in any fashion, you are agreeing to be bound 
 * by the terms of the Microsoft Permissive License.
 *
 * You must not remove this notice, or any other, from this software.
 *
 *
 * ***************************************************************************/

using Microsoft.Scripting.Generation;

namespace Microsoft.Scripting.Ast {
    public class ExpressionStatement : Statement {
        private readonly Expression _expression;

        internal ExpressionStatement(SourceSpan span, Expression expression)
            : base(span) {
            _expression = expression;
        }

        public Expression Expression {
            get { return _expression; }
        }

        protected override object DoExecute(CodeContext context) {
            _expression.Evaluate(context);
            return NextStatement;
        }

        public override void Emit(CodeGen cg) {
            cg.EmitPosition(Start, End);
            // expression needs to be emitted incase it has side-effects.
            _expression.EmitAs(cg, typeof(void));
        }

        public override void Walk(Walker walker) {
            if (walker.Walk(this)) {
                _expression.Walk(walker);
            }
            walker.PostWalk(this);
        }
    }

    public static partial class Ast {
        public static Statement Statement(Expression expression) {
            return Statement(SourceSpan.None, expression);
        }
        public static Statement Statement(SourceSpan span, Expression expression) {
            return new ExpressionStatement(span, expression);
        }
    }
}