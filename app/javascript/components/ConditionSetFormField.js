import React from 'react';
import PropTypes from 'prop-types';

import ConditionFormField from './ConditionFormField';

class ConditionSetFormField extends React.Component {
  static propTypes = {
    hide: PropTypes.bool.isRequired,

    // TODO: Describe these prop types.
    /* eslint-disable react/forbid-prop-types */
    conditions: PropTypes.any,
    formId: PropTypes.any,
    refableQings: PropTypes.any,
    conditionableId: PropTypes.any,
    conditionableType: PropTypes.any,
    namePrefix: PropTypes.any,
    /* eslint-enable */
  };

  constructor(props) {
    super(props);
    const { conditions, formId, refableQings, conditionableId, conditionableType, namePrefix } = this.props;
    // TODO: Improve the `conditions` object;
    //  it currently provides some of this state to children which is unconventional.
    // eslint-disable-next-line react/no-unused-state
    this.state = { conditions, formId, refableQings, conditionableId, conditionableType, namePrefix };
  }

  // If about to show the set and it's empty, add a blank one.
  componentWillReceiveProps(newProps) {
    const { hide } = this.props;
    const { conditions } = this.state;
    if (!newProps.hide && hide && conditions.length === 0) {
      this.handleAddClick();
    }
  }

  handleAddClick = () => {
    this.setState(({ conditions, formId, refableQings, conditionableId, conditionableType }) => ({
      conditions: conditions.concat([{
        key: Math.round(Math.random() * 100000000),
        formId,
        refableQings,
        operatorOptions: [],
        conditionableId,
        conditionableType,
      }]),
    }));
  }

  render() {
    const { hide } = this.props;
    const { conditions, namePrefix } = this.state;

    return (
      <div
        className="condition-set"
        style={{ display: hide ? 'none' : '' }}
      >
        {conditions.map((props, index) => (
          <ConditionFormField
            hide={hide}
            index={index}
            key={props.key || props.id}
            namePrefix={namePrefix}
            {...props}
          />
        ))}
        {/* TODO: Improve a11y. */}
        {/* eslint-disable */}
        <a
          onClick={this.handleAddClick}
          tabIndex="0"
        >
        {/* eslint-enable */}
          <i className="fa fa-plus add-condition" />
          {' '}
          {I18n.t('form_item.add_condition')}
        </a>
      </div>
    );
  }
}

export default ConditionSetFormField;
