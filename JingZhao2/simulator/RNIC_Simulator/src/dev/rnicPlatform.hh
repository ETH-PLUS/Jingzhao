/*
 *======================= START OF LICENSE NOTICE =======================
 *  Copyright (C) 2021 Kang Ning, NCIC, ICT, CAS.
 *  All Rights Reserved.
 *
 *  NO WARRANTY. THE PRODUCT IS PROVIDED BY DEVELOPER "AS IS" AND ANY
 *  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 *  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 *  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL DEVELOPER BE LIABLE FOR
 *  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 *  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 *  GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
 *  IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 *  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THE PRODUCT, EVEN
 *  IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *======================== END OF LICENSE NOTICE ========================
 *  Primary Author: Kang Ning
 *      <kangning18z@ict.ac.cn>
 *  Date: 2021.07.08
 */


/**
 * @file
 * Declaration of top level class for platform with rdma nic. This class
 * just retains pointers to all its children so the children can communicate.
 */

#ifndef __RNIC_PLATFORM_HH__
#define __RNIC_PLATFORM_HH__

#include "dev/platform.hh"
#include "params/RnicPlatform.hh"

class System;

class RnicPlatform : public Platform {
  public:
    /** Pointer to the system */
    System *system;

  public:
    typedef RnicPlatformParams Params;

    /**
     * Do platform initialization stuff
     */
    void init() override;

    RnicPlatform(const Params *p);

  public:
    void postConsoleInt() override;
    void clearConsoleInt() override;

    void postPciInt(int line) override;
    void clearPciInt(int line) override;
};

#endif // __RNIC_PLATFORM_HH__
