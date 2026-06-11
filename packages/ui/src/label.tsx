"use client";

import type { LabelHTMLAttributes } from "react";
import * as React from "react";

import { cn } from "./cn";

export interface LabelProps extends LabelHTMLAttributes<HTMLLabelElement> {}

export const Label = React.forwardRef<HTMLLabelElement, LabelProps>(
  ({ className, ...props }, ref) => {
    return (
      <label
        ref={ref}
        className={cn("text-sm font-medium leading-none", className)}
        {...props}
      />
    );
  }
);

Label.displayName = "Label";

